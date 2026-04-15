//
//  CameraView.swift
//  Provika
//
//  Created by bbdyno on 4/16/26.
//

import SwiftUI

struct CameraView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
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
                modelContext: modelContext
            )
            viewModel.onAppear()
        }
        .onChange(of: isActiveTab) { _, active in
            if active {
                viewModel.onAppear()
            } else {
                viewModel.onDisappear()
            }
        }
    }

    private var cameraContent: some View {
        ZStack {
            CameraPreviewView(
                session: viewModel.captureService.session,
                onTapLocation: { point in
                    viewModel.handleTapFocus(at: point)
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
                        pinchStartZoom = viewModel.captureService.currentZoomFactor
                    }
            )
            .onAppear {
                pinchStartZoom = viewModel.captureService.currentZoomFactor
            }

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
        .overlay(alignment: .bottom) {
            bottomControls
        }
        .overlay(alignment: .bottom) {
            ZoomDialControl(
                zoomFactor: viewModel.captureService.currentZoomFactor,
                minZoom: viewModel.captureService.minZoomFactor,
                maxZoom: viewModel.captureService.maxZoomFactor,
                onZoomChange: { factor in
                    viewModel.captureService.setZoom(factor)
                }
            )
            .padding(.bottom, zoomDialBottomPadding)
        }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            viewModel.updateState()
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 0) {
            recordButton
                .padding(.bottom, 16)

            HStack {
                Spacer()

                Button(action: { viewModel.toggleFlash() }) {
                    Image(systemName: viewModel.isFlashOn ? "bolt.fill" : "bolt.slash")
                        .font(.title2)
                        .foregroundStyle(viewModel.isFlashOn ? .yellow : .white)
                        .frame(width: 50, height: 50)
                }
            }
            .padding(.horizontal, 40)
        }
        .padding(.bottom, 8)
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
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.slash")
                .font(.system(size: 60))
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
