import XCTest
@testable import Provika

final class VideoEvidenceRecordingStateMachineTests: XCTestCase {
    func testEveryRequiredState() {
        XCTAssertEqual(Set(VideoEvidenceRecordingStateMachine.State.allCases.map(\.rawValue)), Set([
            "idle", "preparing", "recording", "stopping", "finalizing", "persisting",
            "buildingClaim", "signing", "verifying", "completed", "interrupted", "failed", "cancelled"
        ]))
    }

    func testIllegalTransitionRejection() {
        var machine = VideoEvidenceRecordingStateMachine()
        XCTAssertEqual(
            machine.transition(.verificationCompleted),
            .rejected(.illegalTransition(from: .idle, event: .verificationCompleted))
        )
        XCTAssertEqual(machine.state, .idle)
    }

    func testNormalStartStopSuccess() {
        let coordinator = VideoEvidenceRecordingCoordinator()
        XCTAssertEqual(coordinator.submit(.start(microphone: .authorized, silentDecision: .disallow)), .accepted(.preparing))
        XCTAssertEqual(coordinator.submit(.preparationCompleted(success: true)), .accepted(.recording))
        XCTAssertEqual(coordinator.submit(.stop), .accepted(.stopping))
        XCTAssertEqual(coordinator.submit(.stopCompleted(success: true)), .accepted(.finalizing))
        XCTAssertEqual(coordinator.submit(.finalizationCompleted(success: true)), .accepted(.persisting))
        XCTAssertEqual(coordinator.submit(.persistenceCompleted(success: true)), .accepted(.buildingClaim))
        XCTAssertEqual(coordinator.submit(.claimBuilt(success: true)), .accepted(.signing))
        XCTAssertEqual(coordinator.submit(.signingCompleted(success: true)), .accepted(.verifying))
        XCTAssertEqual(coordinator.submit(.verificationCompleted(valid: true)), .accepted(.completed))
    }

    func testImmediateStopAfterStart() {
        let coordinator = recordingCoordinator()
        XCTAssertEqual(coordinator.submit(.stop), .accepted(.stopping))
        XCTAssertEqual(coordinator.submit(.stopCompleted(success: true)), .accepted(.finalizing))
    }

    func testRepeatedStartAndStop() {
        let coordinator = VideoEvidenceRecordingCoordinator()
        XCTAssertEqual(coordinator.submit(.start(microphone: .authorized, silentDecision: .disallow)), .accepted(.preparing))
        guard case .rejected = coordinator.submit(.start(microphone: .authorized, silentDecision: .disallow)) else {
            return XCTFail("duplicate start must be rejected")
        }
        XCTAssertEqual(coordinator.submit(.preparationCompleted(success: true)), .accepted(.recording))
        XCTAssertEqual(coordinator.submit(.stop), .accepted(.stopping))
        guard case .rejected = coordinator.submit(.stop) else {
            return XCTFail("duplicate stop must be rejected")
        }
        XCTAssertEqual(coordinator.state, .stopping)
    }

    func testInterruptionMidRecording() {
        let coordinator = recordingCoordinator()
        XCTAssertEqual(coordinator.submit(.interruption), .accepted(.interrupted))
        XCTAssertEqual(coordinator.submit(.recover), .accepted(.idle))
    }

    func testBackgroundInterruption() {
        let coordinator = recordingCoordinator()
        XCTAssertEqual(coordinator.submit(.background), .accepted(.stopping))
    }

    func testPermissionChange() {
        let coordinator = recordingCoordinator()
        XCTAssertEqual(coordinator.submit(.permissionChanged(.denied)), .accepted(.failed))
    }

    func testFinalizeFailure() {
        let coordinator = recordingCoordinator()
        XCTAssertEqual(coordinator.submit(.stop), .accepted(.stopping))
        XCTAssertEqual(coordinator.submit(.stopCompleted(success: false)), .accepted(.failed))
    }

    func testPersistFailure() {
        let coordinator = coordinator(in: .persisting)
        XCTAssertEqual(coordinator.submit(.persistenceCompleted(success: false)), .accepted(.failed))
    }

    func testSignerFailure() {
        let coordinator = coordinator(in: .buildingClaim)
        XCTAssertEqual(coordinator.submit(.claimBuilt(success: true)), .accepted(.signing))
        XCTAssertEqual(coordinator.submit(.signingCompleted(success: false)), .accepted(.failed))
    }

    func testVerificationFailure() {
        let coordinator = coordinator(in: .signing)
        XCTAssertEqual(coordinator.submit(.signingCompleted(success: true)), .accepted(.verifying))
        XCTAssertEqual(coordinator.submit(.verificationCompleted(valid: false)), .accepted(.failed))
    }

    func testCancellationAtEachMajorStage() {
        for state in [
            VideoEvidenceRecordingStateMachine.State.preparing, .recording, .stopping,
            .finalizing, .persisting, .buildingClaim, .signing, .verifying, .interrupted
        ] {
            let coordinator = coordinator(in: state)
            XCTAssertEqual(coordinator.submit(.cancel), .accepted(.cancelled), "state: \(state)")
        }
    }

    func testMicrophoneDeniedSilentPath() {
        let denied = VideoEvidenceRecordingCoordinator()
        XCTAssertEqual(
            denied.submit(.start(microphone: .denied, silentDecision: .disallow)),
            .rejected(.audioPermission(.microphoneRequired))
        )
        XCTAssertNil(denied.audioIncluded)

        let silent = VideoEvidenceRecordingCoordinator()
        XCTAssertEqual(
            silent.submit(.start(microphone: .denied, silentDecision: .allowWhenMicrophoneDenied)),
            .accepted(.preparing)
        )
        XCTAssertEqual(silent.audioIncluded, false)
    }

    func testAudioCaptureStartedButFileHasNoAudioTrack() {
        let coordinator = recordingCoordinator()
        XCTAssertEqual(coordinator.audioIncluded, true)
        XCTAssertEqual(coordinator.state, .recording)
        XCTAssertFalse(coordinator.transitionLog.contains { $0.command.contains("track") })
    }

    func testTransitionLogRedaction() {
        let coordinator = VideoEvidenceRecordingCoordinator(logLimit: 2)
        _ = coordinator.submit(.start(microphone: .authorized, silentDecision: .disallow))
        _ = coordinator.submit(.preparationCompleted(success: true))
        _ = coordinator.submit(.stop)
        XCTAssertEqual(coordinator.transitionLog.count, 2)
        XCTAssertEqual(coordinator.transitionLog.map(\.sequence), [2, 3])
        XCTAssertEqual(coordinator.transitionLog.last?.command, "stop")
        XCTAssertEqual(coordinator.transitionLog.last?.audioIncluded, true)
        let encoded = coordinator.transitionLog.map { "\($0.sequence)|\($0.command)|\($0.from)|\($0.to)" }.joined()
        for forbidden in ["latitude", "longitude", "signature", "private-key", "media-bytes", "user-text"] {
            XCTAssertFalse(encoded.contains(forbidden))
        }
    }

    private func recordingCoordinator() -> VideoEvidenceRecordingCoordinator {
        let coordinator = VideoEvidenceRecordingCoordinator()
        _ = coordinator.submit(.start(microphone: .authorized, silentDecision: .disallow))
        _ = coordinator.submit(.preparationCompleted(success: true))
        return coordinator
    }

    private func coordinator(in target: VideoEvidenceRecordingStateMachine.State) -> VideoEvidenceRecordingCoordinator {
        let coordinator = VideoEvidenceRecordingCoordinator()
        guard target != .idle else { return coordinator }
        _ = coordinator.submit(.start(microphone: .authorized, silentDecision: .disallow))
        guard target != .preparing else { return coordinator }
        _ = coordinator.submit(.preparationCompleted(success: true))
        guard target != .recording else { return coordinator }
        if target == .interrupted {
            _ = coordinator.submit(.interruption)
            return coordinator
        }
        _ = coordinator.submit(.stop)
        guard target != .stopping else { return coordinator }
        _ = coordinator.submit(.stopCompleted(success: true))
        guard target != .finalizing else { return coordinator }
        _ = coordinator.submit(.finalizationCompleted(success: true))
        guard target != .persisting else { return coordinator }
        _ = coordinator.submit(.persistenceCompleted(success: true))
        guard target != .buildingClaim else { return coordinator }
        _ = coordinator.submit(.claimBuilt(success: true))
        guard target != .signing else { return coordinator }
        _ = coordinator.submit(.signingCompleted(success: true))
        return coordinator
    }
}
