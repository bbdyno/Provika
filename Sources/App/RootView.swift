//
//  RootView.swift
//  Provika
//
//  Created by bbdyno on 4/16/26.
//

import SwiftUI

enum AppTab: Int {
    case camera, gallery, settings
}

struct RootView: View {
    @State private var selectedTab = AppTab.camera

    var body: some View {
        TabView(selection: $selectedTab) {
            CameraView(isActiveTab: selectedTab == .camera)
                .tabItem {
                    Label(
                        ProvikaStrings.Localizable.Tab.camera,
                        systemImage: "camera.fill"
                    )
                }
                .tag(AppTab.camera)
                .accessibilityLabel(ProvikaStrings.Localizable.Tab.camera)

            GalleryView()
                .tabItem {
                    Label(
                        ProvikaStrings.Localizable.Tab.gallery,
                        systemImage: "photo.on.rectangle"
                    )
                }
                .tag(AppTab.gallery)
                .accessibilityLabel(ProvikaStrings.Localizable.Tab.gallery)

            SettingsView()
                .tabItem {
                    Label(
                        ProvikaStrings.Localizable.Tab.settings,
                        systemImage: "gearshape.fill"
                    )
                }
                .tag(AppTab.settings)
                .accessibilityLabel(ProvikaStrings.Localizable.Tab.settings)
        }
        .tint(.red)
    }
}
