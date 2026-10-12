//
//  CapturePhotoIntent.swift
//  Provika
//

import AppIntents

// 액션 버튼·Siri·단축어에서 호출되는 "사진 증거 촬영" 인텐트.
// 서명은 앱의 사진 증거 파이프라인이 수행하므로 앱을 연 뒤 요청만 남긴다.
struct CapturePhotoIntent: AppIntent {
    static var title: LocalizedStringResource = "intent.capturePhoto.title"
    static var description = IntentDescription("intent.capturePhoto.description")
    static var openAppWhenRun: Bool = true

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        PendingLaunchAction.shared.request = .capturePhoto
        return .result()
    }
}
