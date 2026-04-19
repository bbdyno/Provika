//
//  ProvikaApp.swift
//  Provika
//
//  Created by bbdyno on 4/16/26.
//

import SwiftData
import SwiftUI

@main
struct ProvikaApp: App {
    @State private var appEnvironment = AppEnvironment()
    @State private var pendingLaunchAction = PendingLaunchAction.shared

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
