import AppIntents

// "Provika 카메라" 컨트롤이 쓰는 인텐트. 잠금 카메라 확장의 진입점이기도 하다.
// 기기가 잠겨 있으면 시스템이 잠금 카메라 확장을, 풀려 있으면 앱을 연다.
@available(iOS 18.0, *)
struct ProvikaCameraCaptureIntent: CameraCaptureIntent {
    static var title: LocalizedStringResource = "intent.openCamera.title"
    static var description = IntentDescription("intent.openCamera.description")
    static var openAppWhenRun: Bool = true

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        PendingLaunchAction.shared.request = .userPreferred
        return .result()
    }
}
