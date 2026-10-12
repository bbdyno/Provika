//
//  CaptureSessionRecoveryPolicy.swift
//  Provika
//

import AVFoundation

// 캡처 세션이 끊겼을 때 무엇을 할지 AVFoundation 객체 없이 판단한다.
// CarPlay·통화·Siri 처럼 마이크만 빼앗기는 상황에서 영상까지 같이 멈추지 않게 하는 것이 목적이다.
enum CaptureSessionRecoveryPolicy {
    enum InterruptionResponse: Equatable {
        /// 오디오 입력만 떼어 내고 영상 캡처는 계속한다.
        case suspendAudioInput
        /// 시스템이 인터럽션을 끝낼 때까지 기다린다. 세션은 스스로 재개된다.
        case waitForSystem
    }

    static func response(to reason: AVCaptureSession.InterruptionReason?) -> InterruptionResponse {
        reason == .audioDeviceInUseByAnotherClient ? .suspendAudioInput : .waitForSystem
    }

    // 차량 마이크로 입력이 넘어가면 헤드유닛이 통화 모드로 바뀌므로 기기 내장 마이크로 되돌린다.
    // 유선 마이크 등 사용자가 직접 연결한 입력은 건드리지 않는다.
    static func shouldPreferBuiltInMicrophone(
        currentInputs: [AVAudioSession.Port],
        availableInputs: [AVAudioSession.Port]
    ) -> Bool {
        currentInputs.contains(.carAudio) && availableInputs.contains(.builtInMic)
    }

    // 선호 입력을 지정하면 그 자체로 경로 변경 알림이 다시 오므로, 기기 연결·해제일 때만 재적용한다.
    static func shouldReapplyPreferredInput(after reason: AVAudioSession.RouteChangeReason?) -> Bool {
        reason == .newDeviceAvailable || reason == .oldDeviceUnavailable
    }

    // 같은 오류가 반복될 때 세션 재시작이 무한히 돌지 않도록 간격을 둔다.
    static let minimumRestartInterval: TimeInterval = 2

    static func shouldRestartAfterRuntimeError(lastRestart: Date?, now: Date) -> Bool {
        guard let lastRestart else { return true }
        return now.timeIntervalSince(lastRestart) >= minimumRestartInterval
    }
}
