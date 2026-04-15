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

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appEnvironment)
                .onAppear {
                    appEnvironment.locationManager.requestAuthorization()
                }
        }
        .modelContainer(for: Recording.self)
    }
}
