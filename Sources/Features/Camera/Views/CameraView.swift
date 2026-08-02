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
            startRecordingIfRequested()
        }
        .onChange(of: isActiveTab) { _, active in
            if active {
                viewModel.onAppear()
                startRecordingIfRequested()
            } else {
                viewModel.onDisappear()
            }
        }
        .onChange(of: pendingLaunchAction.shouldStartRecording) { _, shouldStart in
            if shouldStart {
                startRecordingIfRequested()
            }
        }
        .onChange(of: viewModel.cameraPermissionGranted) { _, granted in
            // 권한을 나중에 승인한 경우에도 pending 요청 소비.
            if granted {
                startRecordingIfRequested()
            }
        }
    }

    // 위젯·액션 버튼 경로로 들어온 녹화 요청을 카메라 준비 상태에서 소비한다.
    // 세션이 활성화되지 않았거나 이미 녹화 중이면 스킵하고 플래그는 유지하여 다음 기회에 재시도.
    private func startRecordingIfRequested() {
        guard pendingLaunchAction.shouldStartRecording else { return }
        guard isActiveTab else { return }
        guard viewModel.cameraPermissionGranted else { return }
        guard !viewModel.isRecording else {
            pendingLaunchAction.shouldStartRecording = false
            return
        }
        // 세션 startSession() 직후 첫 프레임이 올 때까지 약간의 딜레이 필요.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            guard pendingLaunchAction.shouldStartRecording else { return }
            guard !viewModel.isRecording else {
                pendingLaunchAction.shouldStartRecording = false
                return
            }
            viewModel.toggleRecording()
            pendingLaunchAction.shouldStartRecording = false
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

    private var photoEvidencePackageRoot: URL {
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return applicationSupport.appendingPathComponent("PhotoEvidencePackages", isDirectory: true)
    }

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
