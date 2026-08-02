//
//  CameraViewModel.swift
//  Provika
//
//  Created by bbdyno on 4/16/26.
//

import AVFoundation
import SwiftData
import UIKit
import os

@Observable
@MainActor
final class CameraViewModel {

    var isFlashOn = false
    var cameraPermissionGranted = false

    let captureService = CaptureService()

    // captureService가 @Observable이므로 SwiftUI는 아래 computed 프로퍼티 의존성을 그대로 추적한다.
    var isRecording: Bool { captureService.isRecording }
    var elapsedTime: TimeInterval { captureService.elapsedTime }

    private let logger = Logger(subsystem: "com.bbdyno.app.provika", category: "CameraVM")
    private var locationManager: LocationManager?
    private var modelContext: ModelContext?
    private(set) var photoEvidenceCoordinator: PhotoEvidenceVerticalSliceCoordinator?
    private(set) var activeAppPhysicalCaptureControl: ActiveAppPhysicalCaptureControl?

    func configure(locationManager: LocationManager, modelContext: ModelContext, photoEvidencePackageRoot: URL) {
        self.locationManager = locationManager
        self.modelContext = modelContext
        captureService.locationManager = locationManager

        captureService.onRecordingFinished = { [weak self] videoURL, sidecarURL, duration, hash in
            self?.saveRecording(videoURL: videoURL, sidecarURL: sidecarURL, duration: duration, hash: hash)
        }
        photoEvidenceCoordinator = PhotoEvidenceVerticalSliceCoordinator(
            captureService: captureService,
            modelContext: modelContext,
            packageRoot: photoEvidencePackageRoot
        )
        let physicalControl = ActiveAppPhysicalCaptureControl(
            isBusy: { [weak self] in self?.photoEvidenceCoordinator?.state == .capturing },
            capturePhoto: { [weak self] in self?.capturePhotoDirect() },
            startVideo: { [weak self] in self?.startRecording() },
            stopVideo: { [weak self] in self?.stopRecording() }
        )
        activeAppPhysicalCaptureControl = physicalControl
        ActiveAppPhysicalCaptureControl.register(physicalControl, for: captureService.session)
    }

    func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraPermissionGranted = true
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.cameraPermissionGranted = granted
                    if granted {
                        self?.setupCamera()
                    }
                }
            }
        default:
            cameraPermissionGranted = false
        }
    }

    func toggleRecording() {
        activeAppPhysicalCaptureControl?.performOnScreenVideoToggle()
    }

    func capturePhotoEvidence() {
        activeAppPhysicalCaptureControl?.performOnScreenPhoto()
    }

    func handlePinchZoom(scale: CGFloat, initialZoom: CGFloat) {
        let newFactor = initialZoom * scale
        captureService.setDisplayZoom(newFactor)
    }

    func handleTapFocus(at point: CGPoint) {
        captureService.focusAndExpose(at: point)
    }

    func toggleFlash() {
        isFlashOn = captureService.toggleFlash()
    }

    func onAppear() {
        // App Store screenshot automation renders the real SwiftUI surface while
        // skipping the simulator-only camera startup timeout. Production launches
        // never include this argument and continue through the normal permission path.
        if ProcessInfo.processInfo.arguments.contains("-ProvikaScreenshotMode") {
            cameraPermissionGranted = true
            return
        }
        checkCameraPermission()
    }

    func onDisappear() {
        if isRecording {
            stopRecording()
        }
        captureService.stopSession()
    }

    private func startRecording() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        captureService.startRecording()
    }

    private func capturePhotoDirect() {
        photoEvidenceCoordinator?.capturePhotoEvidence()
    }

    private func stopRecording() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        captureService.stopRecording()
    }

    private func setupCamera() {
        captureService.configureSession()
        captureService.startSession()
    }

    private func saveRecording(videoURL: URL, sidecarURL: URL, duration: TimeInterval, hash: String) {
        guard let modelContext else { return }

        let loc = locationManager?.currentLocation
        let startDate = captureService.recordingStartTime ?? Date()

        let recording = Recording(
            id: videoURL.deletingPathExtension().lastPathComponent,
            createdAt: startDate,
            duration: duration,
            fileURL: videoURL,
            sidecarURL: sidecarURL,
            fileHash: hash,
            startLatitude: loc?.coordinate.latitude,
            startLongitude: loc?.coordinate.longitude
        )

        modelContext.insert(recording)
        logger.info("녹화 저장 완료: \(recording.id)")
    }
}
