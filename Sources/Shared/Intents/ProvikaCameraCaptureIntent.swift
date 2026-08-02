import AppIntents

@available(iOS 18.0, *)
struct ProvikaCameraCaptureIntent: CameraCaptureIntent {
    static var title: LocalizedStringResource = "Provika Camera"
    static var description = IntentDescription("Open Provika's locked camera capture experience.")
    static var openAppWhenRun: Bool = true

    init() {}

    func perform() async throws -> some IntentResult {
        .result()
    }
}
