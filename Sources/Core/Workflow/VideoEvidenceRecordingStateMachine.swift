import Foundation

/// Pure transition model for the Video Evidence lifecycle.
///
/// Stop request, writer finalization, persistence, claim construction,
/// signing, and verification intentionally remain separate states so a caller
/// can prove their order without relying on an AVFoundation callback chain.
struct VideoEvidenceRecordingStateMachine: Sendable, Equatable {
    enum State: String, CaseIterable, Codable, Sendable {
        case idle
        case preparing
        case recording
        case stopping
        case finalizing
        case persisting
        case buildingClaim
        case signing
        case verifying
        case completed
        case interrupted
        case failed
        case cancelled
    }

    enum Event: String, Codable, Sendable {
        case prepareRequested
        case preparationCompleted
        case stopRequested
        case finalizationStarted
        case persistenceStarted
        case claimBuildStarted
        case signingStarted
        case verificationStarted
        case verificationCompleted
        case interruptionBegan
        case recoveryRequested
        case failureOccurred
        case cancellationRequested
        case reset
    }

    enum Rejection: Error, Equatable, Sendable {
        case illegalTransition(from: State, event: Event)
    }

    enum Transition: Equatable, Sendable {
        case accepted(from: State, to: State, event: Event)
        case rejected(Rejection)
    }

    private(set) var state: State = .idle

    @discardableResult
    mutating func transition(_ event: Event) -> Transition {
        let previous = state
        guard let next = Self.nextState(from: previous, event: event) else {
            return .rejected(.illegalTransition(from: previous, event: event))
        }
        state = next
        return .accepted(from: previous, to: next, event: event)
    }

    private static func nextState(from state: State, event: Event) -> State? {
        switch (state, event) {
        case (.idle, .prepareRequested), (.failed, .prepareRequested), (.cancelled, .prepareRequested):
            .preparing
        case (.preparing, .preparationCompleted):
            .recording
        case (.recording, .stopRequested):
            .stopping
        case (.stopping, .finalizationStarted):
            .finalizing
        case (.finalizing, .persistenceStarted):
            .persisting
        case (.persisting, .claimBuildStarted):
            .buildingClaim
        case (.buildingClaim, .signingStarted):
            .signing
        case (.signing, .verificationStarted):
            .verifying
        case (.verifying, .verificationCompleted):
            .completed
        case (.preparing, .interruptionBegan), (.recording, .interruptionBegan):
            .interrupted
        case (.interrupted, .recoveryRequested):
            .idle
        case (.preparing, .failureOccurred), (.recording, .failureOccurred),
             (.stopping, .failureOccurred), (.finalizing, .failureOccurred),
             (.persisting, .failureOccurred), (.buildingClaim, .failureOccurred),
             (.signing, .failureOccurred), (.verifying, .failureOccurred),
             (.interrupted, .failureOccurred):
            .failed
        case (.preparing, .cancellationRequested), (.recording, .cancellationRequested),
             (.stopping, .cancellationRequested), (.finalizing, .cancellationRequested),
             (.persisting, .cancellationRequested), (.buildingClaim, .cancellationRequested),
             (.signing, .cancellationRequested), (.verifying, .cancellationRequested),
             (.interrupted, .cancellationRequested):
            .cancelled
        case (.completed, .reset), (.failed, .reset), (.cancelled, .reset):
            .idle
        default:
            nil
        }
    }
}
