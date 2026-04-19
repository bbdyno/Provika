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
    @Environment(PendingLaunchAction.self) private var pendingLaunchAction
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
        // 위젯·액션 버튼에서 녹화 시작 요청이 들어오면 카메라 탭으로 전환.
        // 실제 녹화 트리거는 CameraView가 카메라 세션 준비 상태를 확인하고 수행.
        .onChange(of: pendingLaunchAction.shouldStartRecording) { _, shouldStart in
            if shouldStart {
                selectedTab = .camera
            }
        }
        .onAppear {
            if pendingLaunchAction.shouldStartRecording {
                selectedTab = .camera
            }
        }
    }
}
