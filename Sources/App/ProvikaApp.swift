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
        // GoogleService-Info.plist 기반 자동 구성
        FirebaseApp.configure()
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
