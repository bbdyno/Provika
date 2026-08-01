//
//  ProvikaApp.swift
//  Provika
//
//  Created by bbdyno on 4/16/26.
//

import FirebaseCore
import SwiftData
import SwiftUI

@main
struct ProvikaApp: App {
    @State private var appEnvironment = AppEnvironment()
    @State private var pendingLaunchAction = PendingLaunchAction.shared

    init() {
        // 공개 저장소의 깨끗한 체크아웃에서도 앱과 테스트를 실행할 수 있어야 한다.
        // Firebase 설정 파일이 있는 배포/개발 환경에서만 Analytics를 구성한다.
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appEnvironment)
                .environment(pendingLaunchAction)
                .onAppear {
                    appEnvironment.locationManager.requestAuthorization()
                }
        }
        .modelContainer(for: Recording.self)
    }
}
