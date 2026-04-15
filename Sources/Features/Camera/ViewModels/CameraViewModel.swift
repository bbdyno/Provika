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
final class CameraViewModel {

    var isFlashOn = false
    var cameraPermissionGranted = false
    var isRecording = false
    var elapsedTime: TimeInterval = 0

    let captureService = CaptureService()

    private let logger = Logger(subsystem: "com.bbdyno.app.provika", category: "CameraVM")
    private var locationManager: LocationManager?
    private var modelContext: ModelContext?

    func configure(locationManager: LocationManager, modelContext: ModelContext) {
        self.locationManager = locationManager
        self.modelContext = modelContext

        captureService.onRecordingFinished = { [weak self] videoURL, sidecarURL, duration in
            self?.saveRecording(videoURL: videoURL, sidecarURL: sidecarURL, duration: duration)
        }
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
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    func handlePinchZoom(scale: CGFloat, initialZoom: CGFloat) {
        let newFactor = initialZoom * scale
        captureService.setZoom(newFactor)
    }

    func handleTapFocus(at point: CGPoint) {
        captureService.focusAndExpose(at: point)
    }

    func toggleFlash() {
        isFlashOn = captureService.toggleFlash()
    }

    func onAppear() {
        checkCameraPermission()
    }

    func onDisappear() {
        if isRecording {
            stopRecording()
        }
        captureService.stopSession()
    }

    func updateState() {
        isRecording = captureService.isRecording
        elapsedTime = captureService.elapsedTime
        captureService.currentLocation = locationManager?.currentLocation
    }

    private func startRecording() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()

        captureService.startRecording()
        isRecording = true
    }

    private func stopRecording() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()

        captureService.stopRecording()
        isRecording = false
    }

    private func setupCamera() {
        captureService.configureSession()
        captureService.startSession()
    }

    private func saveRecording(videoURL: URL, sidecarURL: URL, duration: TimeInterval) {
        guard let modelContext else { return }

        var hash = ""
        if let computed = try? HashCalculator.sha256(of: videoURL) {
            hash = computed
        }

        // 실제 영상 파일에서 duration 읽기
        let asset = AVAsset(url: videoURL)
        let actualDuration: TimeInterval
        if let track = asset.tracks(withMediaType: .video).first {
            actualDuration = CMTimeGetSeconds(track.timeRange.duration)
        } else {
            actualDuration = duration
        }

        let loc = locationManager?.currentLocation
        let startDate = captureService.recordingStartTime ?? Date()

        let recording = Recording(
            id: videoURL.deletingPathExtension().lastPathComponent,
            createdAt: startDate,
            duration: actualDuration,
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
