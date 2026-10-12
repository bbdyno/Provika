//
//  ProvikaAppShortcuts.swift
//  Provika
//

import AppIntents

// 설치만으로 단축어 앱·Spotlight·Siri·액션 버튼의 단축어 목록에 노출되는 앱 단축어.
// 문구는 AppShortcuts.xcstrings 에서 번역한다.
struct ProvikaAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartRecordingIntent(),
            phrases: ["Start recording with \(.applicationName)"],
            shortTitle: "intent.startRecording.title",
            systemImageName: "record.circle"
        )
        AppShortcut(
            intent: CapturePhotoIntent(),
            phrases: ["Capture photo evidence with \(.applicationName)"],
            shortTitle: "intent.capturePhoto.title",
            systemImageName: "camera.circle"
        )
    }
}
