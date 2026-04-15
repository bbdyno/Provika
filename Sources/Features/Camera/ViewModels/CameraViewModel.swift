import AVFoundation
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

    func setLocationManager(_ manager: LocationManager) {
        locationManager = manager
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
}
