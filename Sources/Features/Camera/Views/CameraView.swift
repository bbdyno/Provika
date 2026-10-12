//
//  CameraView.swift
//  Provika
//
//  Created by bbdyno on 4/16/26.
//

import SwiftUI

struct CameraView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(PendingLaunchAction.self) private var pendingLaunchAction
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = CameraViewModel()
    @State private var pinchStartZoom: CGFloat = 1.0
    @State private var launchRequestTask: Task<Void, Never>?

    private let zoomDialBottomPadding: CGFloat = 108

    let isActiveTab: Bool

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if viewModel.cameraPermissionGranted {
                cameraContent
            } else {
                permissionDeniedView
            }
        }
        .onAppear {
            viewModel.configure(
                locationManager: appEnvironment.locationManager,
                modelContext: modelContext,
                photoEvidencePackageRoot: photoEvidencePackageRoot
            )
            viewModel.onAppear()
            performLaunchRequestIfNeeded()
        }
        .onChange(of: isActiveTab) { _, active in
            if active {
                viewModel.onAppear()
                performLaunchRequestIfNeeded()
            } else {
                viewModel.onDisappear()
            }
        }
        .onChange(of: pendingLaunchAction.request) { _, request in
            if request != nil {
                performLaunchRequestIfNeeded()
            }
        }
        .onChange(of: viewModel.cameraPermissionGranted) { _, granted in
            // 권한을 나중에 승인한 경우에도 pending 요청 소비.
            if granted {
                performLaunchRequestIfNeeded()
            }
        }
    }

    // 위젯·액션 버튼·단축어 경로로 들어온 요청을 카메라 준비 상태에서 소비한다.
    // 탭이 비활성이거나 권한이 없으면 요청을 유지해 다음 기회에 재시도한다.
    private func performLaunchRequestIfNeeded() {
        guard pendingLaunchAction.request != nil else { return }
        guard isActiveTab else { return }
        guard viewModel.cameraPermissionGranted else { return }
        guard launchRequestTask == nil else { return }

        launchRequestTask = Task { @MainActor in
            defer { launchRequestTask = nil }
            // 콜드 스타트에서는 세션이 뜨는 데 걸리는 시간이 일정하지 않다. 고정 지연 대신 실제로 돌 때까지 기다린다.
            let sessionReady = await viewModel.waitUntilSessionRunning()
            guard let request = pendingLaunchAction.request else { return }
            // 세션이 끝내 뜨지 않았으면 요청을 버린다. 남겨 두면 한참 뒤 엉뚱한 시점에 촬영이 시작된다.
            pendingLaunchAction.request = nil
            guard sessionReady else { return }
            viewModel.perform(QuickLaunchAction.resolve(request))
        }
    }

    private var cameraContent: some View {
        ZStack {
            CameraPreviewView(
                session: viewModel.captureService.session,
                onTapLocation: { point in
                    viewModel.handleTapFocus(at: point)
                },
                onPreviewLayerReady: { previewLayer in
                    viewModel.captureService.attachPreviewLayer(previewLayer)
                }
            )
            .ignoresSafeArea()
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        viewModel.handlePinchZoom(
                            scale: value.magnification,
                            initialZoom: pinchStartZoom
                        )
                    }
                    .onEnded { _ in
                        pinchStartZoom = viewModel.captureService.currentDisplayZoom
                    }
            )
            .onAppear {
                pinchStartZoom = viewModel.captureService.currentDisplayZoom
            }
            #if DEBUG
            .overlay {
                if ScreenshotFixtures.isEnabled,
                   let data = ScreenshotFixtures.cameraPreviewData,
                   let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
            }
            #endif

            // 녹화 중 빨간 테두리
            if viewModel.isRecording {
                RoundedRectangle(cornerRadius: 0)
                    .stroke(.red, lineWidth: 4)
                    .ignoresSafeArea()
            }

            VStack {
                // 상단: 녹화 인디케이터
                HStack {
                    if viewModel.isRecording {
                        RecordingIndicatorView(elapsedTime: viewModel.elapsedTime)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()
            }
        }
        // 줌 다이얼을 먼저 배치해 아래 층에 두고, 녹화·플래시 버튼이 항상 상단에 오도록 한다.
        // 그렇지 않으면 다이얼이 펼쳐졌을 때 배경 Rectangle이 녹화 버튼 위를 덮어 터치를 가로챈다.
        .overlay(alignment: .bottom) {
            ZoomDialControl(
                zoomFactor: viewModel.captureService.currentDisplayZoom,
                minZoom: viewModel.captureService.minDisplayZoom,
                maxZoom: viewModel.captureService.maxDisplayZoom,
                onZoomChange: { factor in
                    viewModel.captureService.setDisplayZoom(factor)
                }
            )
            .padding(.bottom, zoomDialBottomPadding)
        }
        .overlay(alignment: .bottom) {
            bottomControls
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 0) {
            recordButton
                .padding(.bottom, 16)

            HStack {
                photoEvidenceButton

                Spacer()

                Button(action: { viewModel.toggleFlash() }) {
                    Image(systemName: viewModel.isFlashOn ? "bolt.fill" : "bolt.slash")
                        .font(.title2)
                        .foregroundStyle(viewModel.isFlashOn ? .yellow : .white)
                        .frame(width: 50, height: 50)
                }
                .accessibilityLabel(ProvikaStrings.Localizable.Camera.Flash.Accessibility.label)
                .accessibilityHint(ProvikaStrings.Localizable.Camera.Flash.Accessibility.hint)
                .accessibilityValue(
                    viewModel.isFlashOn
                        ? ProvikaStrings.Localizable.Camera.Flash.Accessibility.on
                        : ProvikaStrings.Localizable.Camera.Flash.Accessibility.off
                )
                .accessibilityIdentifier("cameraFlashButton")
            }
            .padding(.horizontal, 40)
        }
        .padding(.bottom, 8)
    }

    private var photoEvidencePackageRoot: URL { FileStorage.photoEvidencePackageRoot }

    private var photoEvidenceButton: some View {
        Button(action: { viewModel.capturePhotoEvidence() }) {
            VStack(spacing: 4) {
                if viewModel.photoEvidenceCoordinator?.state == .capturing {
                    ProgressView()
                } else {
                    Image(systemName: "camera.circle.fill")
                        .font(.title)
                }
                Text(photoEvidenceFeedbackText)
                    .font(.caption2)
            }
            .foregroundStyle(.white)
            .frame(minWidth: 74, minHeight: 50)
        }
        .disabled(viewModel.photoEvidenceCoordinator?.state == .capturing)
        .accessibilityLabel(ProvikaStrings.Localizable.Camera.PhotoEvidence.Accessibility.label)
        .accessibilityHint(ProvikaStrings.Localizable.Camera.PhotoEvidence.Accessibility.hint)
        .accessibilityValue(photoEvidenceFeedbackText)
        .accessibilityIdentifier("capturePhotoEvidenceButton")
    }

    private var photoEvidenceFeedbackText: String {
        switch viewModel.photoEvidenceCoordinator?.state ?? .idle {
        case .idle: ProvikaStrings.Localizable.Camera.PhotoEvidence.idle
        case .capturing: ProvikaStrings.Localizable.Camera.PhotoEvidence.busy
        case .succeeded: ProvikaStrings.Localizable.Camera.PhotoEvidence.success
        case .failed: ProvikaStrings.Localizable.Camera.PhotoEvidence.failure
        }
    }

    private var recordButton: some View {
        Button(action: { viewModel.toggleRecording() }) {
            ZStack {
                Circle()
                    .stroke(.white, lineWidth: 4)
                    .frame(width: 72, height: 72)

                if viewModel.isRecording {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.red)
                        .frame(width: 30, height: 30)
                } else {
                    Circle()
                        .fill(.red)
                        .frame(width: 60, height: 60)
                }
            }
        }
        .accessibilityLabel(
            viewModel.isRecording
                ? ProvikaStrings.Localizable.Camera.Record.stop
                : ProvikaStrings.Localizable.Camera.Record.start
        )
        .accessibilityHint(
            viewModel.isRecording
                ? ProvikaStrings.Localizable.Camera.Record.stop
                : ProvikaStrings.Localizable.Camera.Record.start
        )
        .accessibilityValue(
            viewModel.isRecording
                ? ProvikaStrings.Localizable.Camera.Recording.indicator
                : ProvikaStrings.Localizable.Camera.Record.start
        )
        .accessibilityIdentifier("recordVideoButton")
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text(ProvikaStrings.Localizable.Camera.Permission.Denied.title)
                .font(.title2)
                .foregroundStyle(.white)

            Text(ProvikaStrings.Localizable.Camera.Permission.Denied.message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(ProvikaStrings.Localizable.Settings.title) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
    }
}
