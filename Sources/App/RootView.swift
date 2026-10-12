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
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: AppTab
    @State private var lockedCaptureImportCoordinator: LockedCaptureImportCoordinator?

    init() {
        #if DEBUG
        switch ScreenshotFixtures.requestedScreen {
        case .gallery, .detail:
            _selectedTab = State(initialValue: .gallery)
        case .settings:
            _selectedTab = State(initialValue: .settings)
        case .camera, .none:
            _selectedTab = State(initialValue: .camera)
        }
        #else
        _selectedTab = State(initialValue: .camera)
        #endif
    }

    private func startLockedCaptureImport() {
        guard lockedCaptureImportCoordinator == nil else { return }
        let coordinator = LockedCaptureImportCoordinator(
            dependencies: LockedCaptureEvidenceSealer(modelContext: modelContext).dependencies
        )
        lockedCaptureImportCoordinator = coordinator
        coordinator.startObserving()
    }

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
        .onChange(of: pendingLaunchAction.request) { _, request in
            if request != nil {
                selectedTab = .camera
            }
        }
        .onAppear {
            if pendingLaunchAction.request != nil {
                selectedTab = .camera
            }
            startLockedCaptureImport()
        }
        // 잠금 상태에서 찍은 촬영분은 보호 데이터가 풀린 뒤에야 봉인할 수 있다. 앱이 앞으로 올 때마다 다시 시도한다.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                lockedCaptureImportCoordinator?.retryPendingImports()
            }
        }
    }
}
