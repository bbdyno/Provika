/// Deterministic, UI-independent workflow state machines for evidence operations.
///
/// Callers own operation ID generation. A completion, failure, cancellation, or
/// recovery event is accepted only when it names the current active operation.
public struct EvidenceWorkflowOperationID: Hashable, Sendable, RawRepresentable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: StringLiteralType) {
        self.init(rawValue: value)
    }
}

public enum EvidenceWorkflowTransition<State: Equatable>: Equatable {
    case accepted(State)
    case rejected(EvidenceWorkflowRejection)
}

public enum EvidenceWorkflowRejection: Equatable, Sendable {
    case illegalState
    case staleOperation
    case retryLimitReached
}

public struct CaptureWorkflowStateMachine: EvidenceWorkflowStateMachine {
    public enum State: Equatable, Sendable {
        case idle
        case capturing(operation: EvidenceWorkflowOperationID, failures: Int)
        case interrupted(operation: EvidenceWorkflowOperationID, failures: Int)
        case cancelled(failures: Int)
        case failed(failures: Int)
        case completed
    }

    public enum Event: Equatable, Sendable {
        case start(EvidenceWorkflowOperationID)
        case complete(EvidenceWorkflowOperationID)
        case fail(EvidenceWorkflowOperationID)
        case cancel(EvidenceWorkflowOperationID)
        case interrupt(EvidenceWorkflowOperationID)
        case recover(EvidenceWorkflowOperationID)
        case retry(EvidenceWorkflowOperationID)
        case reset
    }

    public private(set) var state: State
    public let maximumFailures: Int

    public init(maximumFailures: Int = 3) {
        self.maximumFailures = max(1, maximumFailures)
        self.state = .idle
    }

    @discardableResult public mutating func transition(_ event: Event) -> EvidenceWorkflowTransition<State> {
        let engine = EvidenceWorkflowEngine(maximumFailures: maximumFailures)
        let result = engine.apply(state: state.engineState, event: event.engineEvent)
        guard case let .accepted(next) = result else { return .rejected(result.rejection!) }
        state = State(engineState: next)
        return .accepted(state)
    }
}

public struct VerificationWorkflowStateMachine: EvidenceWorkflowStateMachine {
    public enum State: Equatable, Sendable {
        case idle
        case verifying(operation: EvidenceWorkflowOperationID, failures: Int)
        case interrupted(operation: EvidenceWorkflowOperationID, failures: Int)
        case cancelled(failures: Int)
        case failed(failures: Int)
        case completed
    }

    public enum Event: Equatable, Sendable {
        case start(EvidenceWorkflowOperationID)
        case complete(EvidenceWorkflowOperationID)
        case fail(EvidenceWorkflowOperationID)
        case cancel(EvidenceWorkflowOperationID)
        case interrupt(EvidenceWorkflowOperationID)
        case recover(EvidenceWorkflowOperationID)
        case retry(EvidenceWorkflowOperationID)
        case reset
    }

    public private(set) var state: State
    public let maximumFailures: Int

    public init(maximumFailures: Int = 3) {
        self.maximumFailures = max(1, maximumFailures)
        self.state = .idle
    }

    @discardableResult public mutating func transition(_ event: Event) -> EvidenceWorkflowTransition<State> {
        let engine = EvidenceWorkflowEngine(maximumFailures: maximumFailures)
        let result = engine.apply(state: state.engineState, event: event.engineEvent)
        guard case let .accepted(next) = result else { return .rejected(result.rejection!) }
        state = State(engineState: next)
        return .accepted(state)
    }
}

public struct ExportWorkflowStateMachine: EvidenceWorkflowStateMachine {
    public enum State: Equatable, Sendable {
        case idle
        case exporting(operation: EvidenceWorkflowOperationID, failures: Int)
        case interrupted(operation: EvidenceWorkflowOperationID, failures: Int)
        case cancelled(failures: Int)
        case failed(failures: Int)
        case completed
    }

    public enum Event: Equatable, Sendable {
        case start(EvidenceWorkflowOperationID)
        case complete(EvidenceWorkflowOperationID)
        case fail(EvidenceWorkflowOperationID)
        case cancel(EvidenceWorkflowOperationID)
        case interrupt(EvidenceWorkflowOperationID)
        case recover(EvidenceWorkflowOperationID)
        case retry(EvidenceWorkflowOperationID)
        case reset
    }

    public private(set) var state: State
    public let maximumFailures: Int

    public init(maximumFailures: Int = 3) {
        self.maximumFailures = max(1, maximumFailures)
        self.state = .idle
    }

    @discardableResult public mutating func transition(_ event: Event) -> EvidenceWorkflowTransition<State> {
        let engine = EvidenceWorkflowEngine(maximumFailures: maximumFailures)
        let result = engine.apply(state: state.engineState, event: event.engineEvent)
        guard case let .accepted(next) = result else { return .rejected(result.rejection!) }
        state = State(engineState: next)
        return .accepted(state)
    }
}

public protocol EvidenceWorkflowStateMachine {
    associatedtype State: Equatable
    associatedtype Event
    var state: State { get }
    var maximumFailures: Int { get }
    mutating func transition(_ event: Event) -> EvidenceWorkflowTransition<State>
}

private enum EvidenceWorkflowEngineState: Equatable {
    case idle
    case active(EvidenceWorkflowOperationID, Int)
    case interrupted(EvidenceWorkflowOperationID, Int)
    case cancelled(Int)
    case failed(Int)
    case completed
}

private enum EvidenceWorkflowEngineEvent {
    case start(EvidenceWorkflowOperationID), complete(EvidenceWorkflowOperationID), fail(EvidenceWorkflowOperationID)
    case cancel(EvidenceWorkflowOperationID), interrupt(EvidenceWorkflowOperationID), recover(EvidenceWorkflowOperationID)
    case retry(EvidenceWorkflowOperationID), reset
}

private struct EvidenceWorkflowEngine {
    let maximumFailures: Int

    func apply(state: EvidenceWorkflowEngineState, event: EvidenceWorkflowEngineEvent) -> EvidenceWorkflowTransition<EvidenceWorkflowEngineState> {
        switch (state, event) {
        case (.idle, .start(let id)):
            return .accepted(.active(id, 0))
        case (.active(let id, _), .complete(let eventID)):
            return id == eventID ? .accepted(.completed) : .rejected(.staleOperation)
        case (.active(let id, let failures), .fail(let eventID)):
            guard id == eventID else { return .rejected(.staleOperation) }
            return .accepted(.failed(failures + 1))
        case (.active(let id, let failures), .cancel(let eventID)):
            return id == eventID ? .accepted(.cancelled(failures)) : .rejected(.staleOperation)
        case (.active(let id, let failures), .interrupt(let eventID)):
            return id == eventID ? .accepted(.interrupted(id, failures)) : .rejected(.staleOperation)
        case (.interrupted(let id, let failures), .recover(let eventID)):
            return id == eventID ? .accepted(.active(id, failures)) : .rejected(.staleOperation)
        case (.failed(let failures), .retry(let id)) where failures < maximumFailures:
            return .accepted(.active(id, failures))
        case (.cancelled(let failures), .retry(let id)):
            return .accepted(.active(id, failures))
        case (.failed, .retry):
            return .rejected(.retryLimitReached)
        case (.cancelled, .reset), (.failed, .reset), (.completed, .reset):
            return .accepted(.idle)
        default:
            return .rejected(.illegalState)
        }
    }
}

private extension EvidenceWorkflowTransition {
    var rejection: EvidenceWorkflowRejection? {
        guard case let .rejected(reason) = self else { return nil }
        return reason
    }
}

private extension CaptureWorkflowStateMachine.State {
    var engineState: EvidenceWorkflowEngineState {
        switch self {
        case .idle: .idle
        case .capturing(let id, let failures): .active(id, failures)
        case .interrupted(let id, let failures): .interrupted(id, failures)
        case .cancelled(let failures): .cancelled(failures)
        case .failed(let failures): .failed(failures)
        case .completed: .completed
        }
    }
    init(engineState: EvidenceWorkflowEngineState) {
        switch engineState {
        case .idle: self = .idle
        case .active(let id, let failures): self = .capturing(operation: id, failures: failures)
        case .interrupted(let id, let failures): self = .interrupted(operation: id, failures: failures)
        case .cancelled(let failures): self = .cancelled(failures: failures)
        case .failed(let failures): self = .failed(failures: failures)
        case .completed: self = .completed
        }
    }
}

private extension VerificationWorkflowStateMachine.State {
    var engineState: EvidenceWorkflowEngineState {
        switch self {
        case .idle: .idle
        case .verifying(let id, let failures): .active(id, failures)
        case .interrupted(let id, let failures): .interrupted(id, failures)
        case .cancelled(let failures): .cancelled(failures)
        case .failed(let failures): .failed(failures)
        case .completed: .completed
        }
    }
    init(engineState: EvidenceWorkflowEngineState) {
        switch engineState {
        case .idle: self = .idle
        case .active(let id, let failures): self = .verifying(operation: id, failures: failures)
        case .interrupted(let id, let failures): self = .interrupted(operation: id, failures: failures)
        case .cancelled(let failures): self = .cancelled(failures: failures)
        case .failed(let failures): self = .failed(failures: failures)
        case .completed: self = .completed
        }
    }
}

private extension ExportWorkflowStateMachine.State {
    var engineState: EvidenceWorkflowEngineState {
        switch self {
        case .idle: .idle
        case .exporting(let id, let failures): .active(id, failures)
        case .interrupted(let id, let failures): .interrupted(id, failures)
        case .cancelled(let failures): .cancelled(failures)
        case .failed(let failures): .failed(failures)
        case .completed: .completed
        }
    }
    init(engineState: EvidenceWorkflowEngineState) {
        switch engineState {
        case .idle: self = .idle
        case .active(let id, let failures): self = .exporting(operation: id, failures: failures)
        case .interrupted(let id, let failures): self = .interrupted(operation: id, failures: failures)
        case .cancelled(let failures): self = .cancelled(failures: failures)
        case .failed(let failures): self = .failed(failures: failures)
        case .completed: self = .completed
        }
    }
}

private extension CaptureWorkflowStateMachine.Event {
    var engineEvent: EvidenceWorkflowEngineEvent {
        switch self { case .start(let id): .start(id); case .complete(let id): .complete(id); case .fail(let id): .fail(id); case .cancel(let id): .cancel(id); case .interrupt(let id): .interrupt(id); case .recover(let id): .recover(id); case .retry(let id): .retry(id); case .reset: .reset }
    }
}
private extension VerificationWorkflowStateMachine.Event {
    var engineEvent: EvidenceWorkflowEngineEvent {
        switch self { case .start(let id): .start(id); case .complete(let id): .complete(id); case .fail(let id): .fail(id); case .cancel(let id): .cancel(id); case .interrupt(let id): .interrupt(id); case .recover(let id): .recover(id); case .retry(let id): .retry(id); case .reset: .reset }
    }
}
private extension ExportWorkflowStateMachine.Event {
    var engineEvent: EvidenceWorkflowEngineEvent {
        switch self { case .start(let id): .start(id); case .complete(let id): .complete(id); case .fail(let id): .fail(id); case .cancel(let id): .cancel(id); case .interrupt(let id): .interrupt(id); case .recover(let id): .recover(id); case .retry(let id): .retry(id); case .reset: .reset }
    }
}
