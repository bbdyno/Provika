//
//  StartRecordingIntent.swift
//  Provika
//
//  Created by bbdyno on 4/19/26.
//

import AppIntents

// Control Widget·액션 버튼·Siri·단축어에서 공통으로 호출되는 "즉시 녹화 시작" 인텐트.
// openAppWhenRun = true 이므로 시스템은 앱을 깨운 뒤 앱 프로세스에서 perform()을 호출한다.
struct StartRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "intent.startRecording.title"
    static var description = IntentDescription("intent.startRecording.description")
    static var openAppWhenRun: Bool = true

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        PendingLaunchAction.shared.shouldStartRecording = true
        return .result()
    }
}
