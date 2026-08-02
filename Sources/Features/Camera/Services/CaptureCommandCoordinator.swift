import Foundation

/// Where an input originated. This is diagnostic provenance only: it is
/// deliberately not carried by a recording or evidence claim, and must never
/// participate in evidence validity or signing.
@frozen public enum CaptureCommandSource: String, CaseIterable, Codable, Sendable {
    case onScreen = "on-screen"
    case physicalPrimary = "physical-primary"
    case physicalSecondary = "physical-secondary"
    case activeAppIntent = "active-app-intent"

    fileprivate var requiresPhysicalCapability: Bool {
        switch self {
        case .physicalPrimary, .physicalSecondary: true
        case .onScreen, .activeAppIntent: false
        }
    }

    /// Keep this diagnostic representation independent of compiler-synthesized
    /// enum coding. It is intentionally just the frozen source value; it is
    /// never an evidence, signature, or validity field.
    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        guard let source = Self(rawValue: value) else {
            throw DecodingError.dataCorruptedError(
                in: try decoder.singleValueContainer(),
                debugDescription: "Unknown capture command source"
            )
        }
        self = source
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// A framework-free command stream for recording orchestration.
///
/// Platform adapters translate their events into this type. In particular,
/// adapters, not this coordinator, own any API availability checks for a
/// physical input framework. The injected runtime capabilities are the final
/// acceptance gate, which keeps this type independent of device model names.
public enum CaptureCommand: Codable, Equatable, Sendable {
    case start
    case stop
    case ended
    case preparationFinished(success: Bool)
    case stopFinished(success: Bool)
    case finalizationFinished(success: Bool)
    case persistenceFinished(success: Bool)
    case appBackgrounded
    case interruptionBegan
    case interruptionEnded
    case permissionChanged(granted: Bool)
    case terminationRequested
}

public final class CaptureCommandCoordinator {
    public enum State: Equatable, Sendable {
        case idle
        case preparing
        case capturing
        case stopping
        case finalizing
        case persisting
        case interrupted
        case failed
        case terminated
    }

    public enum Rejection: Equatable, Sendable {
        case unavailablePhysicalInput(CaptureCommandSource)
        case busy(State)
        case invalidState(State)
        case permissionDenied
        case terminated
    }

    public enum Outcome: Equatable, Sendable {
        case accepted(State)
        case ignoredDuplicateEnded
        case rejected(Rejection)
    }

    public struct RuntimeCapabilities: Sendable {
        public var physicalPrimaryAvailable: @Sendable () -> Bool
        public var physicalSecondaryAvailable: @Sendable () -> Bool

        public init(
            physicalPrimaryAvailable: @escaping @Sendable () -> Bool = { false },
            physicalSecondaryAvailable: @escaping @Sendable () -> Bool = { false }
        ) {
            self.physicalPrimaryAvailable = physicalPrimaryAvailable
            self.physicalSecondaryAvailable = physicalSecondaryAvailable
        }

        fileprivate func accepts(_ source: CaptureCommandSource) -> Bool {
            switch source {
            case .onScreen, .activeAppIntent: true
            case .physicalPrimary: physicalPrimaryAvailable()
            case .physicalSecondary: physicalSecondaryAvailable()
            }
        }
    }

    public struct Dependencies {
        public var prepare: () -> Void
        public var stop: () -> Void
        public var finalize: () -> Void
        public var persist: () -> Void
        public var terminate: () -> Void

        public init(
            prepare: @escaping () -> Void = {},
            stop: @escaping () -> Void = {},
            finalize: @escaping () -> Void = {},
            persist: @escaping () -> Void = {},
            terminate: @escaping () -> Void = {}
        ) {
            self.prepare = prepare
            self.stop = stop
            self.finalize = finalize
            self.persist = persist
            self.terminate = terminate
        }
    }

    public struct Diagnostic: Equatable, Sendable {
        public let command: CaptureCommand
        public let source: CaptureCommandSource
        public let outcome: Outcome
    }

    public private(set) var state: State = .idle
    public private(set) var diagnostics: [Diagnostic] = []

    private let capabilities: RuntimeCapabilities
    private let dependencies: Dependencies
    private let lock = NSRecursiveLock()
    private var permissionGranted: Bool

    public init(
        capabilities: RuntimeCapabilities = .init(),
        permissionGranted: Bool = true,
        dependencies: Dependencies = .init()
    ) {
        self.capabilities = capabilities
        self.permissionGranted = permissionGranted
        self.dependencies = dependencies
    }

    /// The sole command path. Sources affect only trigger availability and
    /// diagnostics; they never change recording or evidence semantics.
    ///
    /// An unavailable physical trigger is rejected before it can begin a
    /// capture. The caller may then use the always-supported on-screen source
    /// through this same command path; no device model or alternate capture
    /// implementation is involved in that fallback.
    @discardableResult
    public func submit(_ command: CaptureCommand, from source: CaptureCommandSource) -> Outcome {
        lock.lock()
        defer { lock.unlock() }

        let outcome: Outcome
        if command.startsPhysicalCapture, source.requiresPhysicalCapability {
            guard capabilities.accepts(source) else {
                outcome = .rejected(.unavailablePhysicalInput(source))
                diagnostics.append(.init(command: command, source: source, outcome: outcome))
                return outcome
            }
        }
        outcome = apply(command)
        diagnostics.append(.init(command: command, source: source, outcome: outcome))
        return outcome
    }

    private func apply(_ command: CaptureCommand) -> Outcome {
        if state == .terminated { return .rejected(.terminated) }

        switch command {
        case .ended:
            return .ignoredDuplicateEnded
        case .start:
            guard permissionGranted else { return .rejected(.permissionDenied) }
            guard state != .interrupted else { return .rejected(.invalidState(state)) }
            guard state == .idle || state == .failed else {
                return .rejected(.busy(state))
            }
            state = .preparing
            dependencies.prepare()
        case .stop:
            guard state == .capturing || state == .preparing || state == .interrupted else {
                return .rejected(state.isBusy ? .busy(state) : .invalidState(state))
            }
            state = .stopping
            dependencies.stop()
        case .preparationFinished(let success):
            guard state == .preparing else { return .rejected(.invalidState(state)) }
            state = success ? .capturing : .failed
        case .stopFinished(let success):
            guard state == .stopping else { return .rejected(.invalidState(state)) }
            if success {
                state = .finalizing
                dependencies.finalize()
            } else {
                state = .failed
            }
        case .finalizationFinished(let success):
            guard state == .finalizing else { return .rejected(.invalidState(state)) }
            if success {
                state = .persisting
                dependencies.persist()
            } else {
                state = .failed
            }
        case .persistenceFinished(let success):
            guard state == .persisting else { return .rejected(.invalidState(state)) }
            state = success ? .idle : .failed
        case .appBackgrounded:
            switch state {
            case .capturing, .preparing:
                state = .stopping
                dependencies.stop()
            case .stopping, .finalizing, .persisting:
                break // Finishing work is serialized and allowed to drain.
            case .idle, .failed, .interrupted:
                break
            case .terminated:
                break
            }
        case .interruptionBegan:
            switch state {
            case .capturing, .preparing:
                state = .stopping
                dependencies.stop()
            case .stopping, .finalizing, .persisting:
                break // Finishing work is serialized and allowed to drain.
            case .idle, .failed:
                state = .interrupted
            case .interrupted:
                break
            case .terminated:
                break
            }
        case .interruptionEnded:
            guard state == .interrupted else { return .rejected(.invalidState(state)) }
            state = .idle
        case .permissionChanged(let granted):
            permissionGranted = granted
            if !granted, state == .capturing || state == .preparing {
                state = .stopping
                dependencies.stop()
            }
        case .terminationRequested:
            if state == .capturing || state == .preparing || state == .interrupted {
                dependencies.stop()
            }
            state = .terminated
            dependencies.terminate()
        }
        return .accepted(state)
    }
}

private extension CaptureCommand {
    /// Starting is the only command that begins a physical capture. A stop is
    /// deliberately never capability-gated: runtime availability may change
    /// after an accepted start, and every accepted capture must still drain.
    var startsPhysicalCapture: Bool {
        switch self {
        case .start: true
        case .stop,
             .ended,
             .preparationFinished,
             .stopFinished,
             .finalizationFinished,
             .persistenceFinished,
             .appBackgrounded,
             .interruptionBegan,
             .interruptionEnded,
             .permissionChanged,
             .terminationRequested:
            false
        }
    }
}

private extension CaptureCommandCoordinator.State {
    var isBusy: Bool {
        switch self {
        case .preparing, .stopping, .finalizing, .persisting: true
        case .idle, .capturing, .interrupted, .failed, .terminated: false
        }
    }
}
