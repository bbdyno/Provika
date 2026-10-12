import AVFoundation
import XCTest
@testable import Provika

final class CaptureSessionRecoveryPolicyTests: XCTestCase {
    func testAudioDeviceConflictSuspendsOnlyAudioInput() {
        XCTAssertEqual(
            CaptureSessionRecoveryPolicy.response(to: .audioDeviceInUseByAnotherClient),
            .suspendAudioInput
        )
    }

    func testOtherInterruptionsWaitForSystem() {
        let reasons: [AVCaptureSession.InterruptionReason?] = [
            .videoDeviceNotAvailableInBackground,
            .videoDeviceInUseByAnotherClient,
            .videoDeviceNotAvailableWithMultipleForegroundApps,
            .videoDeviceNotAvailableDueToSystemPressure,
            nil
        ]
        for reason in reasons {
            XCTAssertEqual(CaptureSessionRecoveryPolicy.response(to: reason), .waitForSystem)
        }
    }

    func testCarMicrophoneIsReplacedByBuiltInMicrophone() {
        XCTAssertTrue(
            CaptureSessionRecoveryPolicy.shouldPreferBuiltInMicrophone(
                currentInputs: [.carAudio],
                availableInputs: [.carAudio, .builtInMic]
            )
        )
    }

    func testUserAttachedMicrophoneIsLeftAlone() {
        XCTAssertFalse(
            CaptureSessionRecoveryPolicy.shouldPreferBuiltInMicrophone(
                currentInputs: [.headsetMic],
                availableInputs: [.headsetMic, .builtInMic]
            )
        )
        XCTAssertFalse(
            CaptureSessionRecoveryPolicy.shouldPreferBuiltInMicrophone(
                currentInputs: [.carAudio],
                availableInputs: [.carAudio]
            )
        )
    }

    func testPreferredInputIsReappliedOnlyWhenDevicesChange() {
        XCTAssertTrue(CaptureSessionRecoveryPolicy.shouldReapplyPreferredInput(after: .newDeviceAvailable))
        XCTAssertTrue(CaptureSessionRecoveryPolicy.shouldReapplyPreferredInput(after: .oldDeviceUnavailable))
        // 선호 입력 지정이 스스로 일으키는 알림에는 반응하지 않아야 루프가 생기지 않는다.
        XCTAssertFalse(CaptureSessionRecoveryPolicy.shouldReapplyPreferredInput(after: .override))
        XCTAssertFalse(CaptureSessionRecoveryPolicy.shouldReapplyPreferredInput(after: .routeConfigurationChange))
        XCTAssertFalse(CaptureSessionRecoveryPolicy.shouldReapplyPreferredInput(after: nil))
    }

    func testRuntimeErrorRestartIsRateLimited() {
        let now = Date()
        XCTAssertTrue(CaptureSessionRecoveryPolicy.shouldRestartAfterRuntimeError(lastRestart: nil, now: now))
        XCTAssertFalse(
            CaptureSessionRecoveryPolicy.shouldRestartAfterRuntimeError(
                lastRestart: now.addingTimeInterval(-0.5),
                now: now
            )
        )
        XCTAssertTrue(
            CaptureSessionRecoveryPolicy.shouldRestartAfterRuntimeError(
                lastRestart: now.addingTimeInterval(-3),
                now: now
            )
        )
    }
}
