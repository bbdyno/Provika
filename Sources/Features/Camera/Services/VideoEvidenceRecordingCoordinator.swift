import Foundation

enum VideoMicrophoneAuthorization: String, Codable, CaseIterable, Sendable {
    case authorized
    case denied
    case restricted
    case notDetermined = "not-determined"
}

enum VideoSilentRecordingDecision: String, Codable, Sendable {
    case disallow
    case allowWhenMicrophoneDenied = "allow-silent-when-microphone-denied"
}

struct VideoAudioPermissionObservation: Codable, Equatable, Sendable {
    let microphoneAuthorization: VideoMicrophoneAuthorization
    let silentRecordingDecision: VideoSilentRecordingDecision
    let audioIncluded: Bool
}

enum VideoAudioPermissionPolicy {
    enum Outcome: Equatable, Sendable {
        case allowed(VideoAudioPermissionObservation)
        case denied(guidance: Guidance)
    }

    enum Guidance: String, Equatable, Sendable {
        case requestMicrophonePermission = "request-microphone-permission"
        case microphoneRequired = "microphone-required-by-policy"
    }

    static func evaluate(
        microphone: VideoMicrophoneAuthorization,
        silentDecision: VideoSilentRecordingDecision
    ) -> Outcome {
        switch microphone {
        case .authorized:
            .allowed(.init(
                microphoneAuthorization: microphone,
                silentRecordingDecision: silentDecision,
                audioIncluded: true
            ))
        case .denied where silentDecision == .allowWhenMicrophoneDenied,
             .restricted where silentDecision == .allowWhenMicrophoneDenied:
            .allowed(.init(
                microphoneAuthorization: microphone,
                silentRecordingDecision: silentDecision,
                audioIncluded: false
            ))
        case .notDetermined:
            .denied(guidance: .requestMicrophonePermission)
        case .denied, .restricted:
            .denied(guidance: .microphoneRequired)
        }
    }
}

/// Strictly serialized coordinator around `VideoEvidenceRecordingStateMachine`.
/// The bounded transitionLog contains machine values only: no location,
/// user-authored text, media bytes, signature, or key material.
final class VideoEvidenceRecordingCoordinator: @unchecked Sendable {
    enum Command: Equatable, Sendable {
        case start(microphone: VideoMicrophoneAuthorization, silentDecision: VideoSilentRecordingDecision)
        case preparationCompleted(success: Bool)
        case stop
        case stopCompleted(success: Bool)
        case finalizationCompleted(success: Bool)
        case persistenceCompleted(success: Bool)
        case claimBuilt(success: Bool)
        case signingCompleted(success: Bool)
        case verificationCompleted(valid: Bool)
        case background
        case interruption
        case permissionChanged(VideoMicrophoneAuthorization)
        case writerFailure
        case cancel
        case recover
        case reset
    }

    enum Rejection: Error, Equatable, Sendable {
        case audioPermission(VideoAudioPermissionPolicy.Guidance)
        case illegalTransition(VideoEvidenceRecordingStateMachine.Rejection)
    }

    enum Outcome: Equatable, Sendable {
        case accepted(VideoEvidenceRecordingStateMachine.State)
        case rejected(Rejection)
    }

    struct TransitionLogEntry: Equatable, Sendable {
        let sequence: UInt64
        let command: String
        let from: VideoEvidenceRecordingStateMachine.State
        let to: VideoEvidenceRecordingStateMachine.State
        let accepted: Bool
        let audioIncluded: Bool?
    }

    struct Dependencies: Sendable {
        var prepare: @Sendable () -> Void
        var requestStop: @Sendable () -> Void
        var beginFinalization: @Sendable () -> Void
        var persist: @Sendable () -> Void
        var buildClaim: @Sendable () -> Void
        var sign: @Sendable () -> Void
        var verify: @Sendable () -> Void

        init(
            prepare: @escaping @Sendable () -> Void = {},
            requestStop: @escaping @Sendable () -> Void = {},
            beginFinalization: @escaping @Sendable () -> Void = {},
            persist: @escaping @Sendable () -> Void = {},
            buildClaim: @escaping @Sendable () -> Void = {},
            sign: @escaping @Sendable () -> Void = {},
            verify: @escaping @Sendable () -> Void = {}
        ) {
            self.prepare = prepare
            self.requestStop = requestStop
            self.beginFinalization = beginFinalization
            self.persist = persist
            self.buildClaim = buildClaim
            self.sign = sign
            self.verify = verify
        }
    }

    private let lock = NSRecursiveLock()
    private let dependencies: Dependencies
    private let logLimit: Int
    private var machine = VideoEvidenceRecordingStateMachine()
    private var sequence: UInt64 = 0

    private(set) var transitionLog: [TransitionLogEntry] = []
    private(set) var audioObservation: VideoAudioPermissionObservation?

    var state: VideoEvidenceRecordingStateMachine.State {
        lock.withLock { machine.state }
    }

    var audioIncluded: Bool? {
        lock.withLock { audioObservation?.audioIncluded }
    }

    init(dependencies: Dependencies = .init(), logLimit: Int = 128) {
        self.dependencies = dependencies
        self.logLimit = max(1, logLimit)
    }

    @discardableResult
    func submit(_ command: Command) -> Outcome {
        lock.withLock {
            let before = machine.state
            let outcome: Outcome
            switch command {
            case let .start(microphone, silentDecision):
                switch VideoAudioPermissionPolicy.evaluate(microphone: microphone, silentDecision: silentDecision) {
                case let .allowed(observation):
                    audioObservation = observation
                    outcome = apply(.prepareRequested, action: dependencies.prepare)
                case let .denied(guidance):
                    outcome = .rejected(.audioPermission(guidance))
                }
            case let .preparationCompleted(success):
                outcome = success ? apply(.preparationCompleted) : apply(.failureOccurred)
            case .stop:
                outcome = apply(.stopRequested, action: dependencies.requestStop)
            case let .stopCompleted(success):
                outcome = success ? apply(.finalizationStarted, action: dependencies.beginFinalization) : apply(.failureOccurred)
            case let .finalizationCompleted(success):
                outcome = success ? apply(.persistenceStarted, action: dependencies.persist) : apply(.failureOccurred)
            case let .persistenceCompleted(success):
                outcome = success ? apply(.claimBuildStarted, action: dependencies.buildClaim) : apply(.failureOccurred)
            case let .claimBuilt(success):
                outcome = success ? apply(.signingStarted, action: dependencies.sign) : apply(.failureOccurred)
            case let .signingCompleted(success):
                outcome = success ? apply(.verificationStarted, action: dependencies.verify) : apply(.failureOccurred)
            case let .verificationCompleted(valid):
                outcome = valid ? apply(.verificationCompleted) : apply(.failureOccurred)
            case .background:
                outcome = machine.state == .recording ? apply(.stopRequested, action: dependencies.requestStop) : reject(.illegalTransition(from: machine.state, event: .stopRequested))
            case .interruption:
                outcome = apply(.interruptionBegan)
            case let .permissionChanged(authorization):
                if authorization == .authorized {
                    outcome = reject(.illegalTransition(from: machine.state, event: .failureOccurred))
                } else {
                    outcome = apply(.failureOccurred)
                }
            case .writerFailure:
                outcome = apply(.failureOccurred)
            case .cancel:
                outcome = apply(.cancellationRequested)
            case .recover:
                outcome = apply(.recoveryRequested)
            case .reset:
                outcome = apply(.reset)
            }
            appendLog(command: command.label, from: before, outcome: outcome)
            return outcome
        }
    }

    private func apply(_ event: VideoEvidenceRecordingStateMachine.Event, action: () -> Void = {}) -> Outcome {
        switch machine.transition(event) {
        case let .accepted(_, to, _):
            action()
            return .accepted(to)
        case let .rejected(reason):
            return .rejected(.illegalTransition(reason))
        }
    }

    private func reject(_ reason: VideoEvidenceRecordingStateMachine.Rejection) -> Outcome {
        .rejected(.illegalTransition(reason))
    }

    private func appendLog(command: String, from: VideoEvidenceRecordingStateMachine.State, outcome: Outcome) {
        sequence &+= 1
        let to: VideoEvidenceRecordingStateMachine.State
        let accepted: Bool
        switch outcome {
        case let .accepted(state):
            to = state
            accepted = true
        case .rejected:
            to = machine.state
            accepted = false
        }
        transitionLog.append(.init(
            sequence: sequence,
            command: command,
            from: from,
            to: to,
            accepted: accepted,
            audioIncluded: audioObservation?.audioIncluded
        ))
        if transitionLog.count > logLimit {
            transitionLog.removeFirst(transitionLog.count - logLimit)
        }
    }
}

private extension VideoEvidenceRecordingCoordinator.Command {
    var label: String {
        switch self {
        case .start: "start"
        case .preparationCompleted: "preparation-completed"
        case .stop: "stop"
        case .stopCompleted: "stop-completed"
        case .finalizationCompleted: "finalization-completed"
        case .persistenceCompleted: "persistence-completed"
        case .claimBuilt: "claim-built"
        case .signingCompleted: "signing-completed"
        case .verificationCompleted: "verification-completed"
        case .background: "background"
        case .interruption: "interruption"
        case .permissionChanged: "permission-change"
        case .writerFailure: "writerFailure"
        case .cancel: "cancel"
        case .recover: "recover"
        case .reset: "reset"
        }
    }
}

private extension NSRecursiveLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
