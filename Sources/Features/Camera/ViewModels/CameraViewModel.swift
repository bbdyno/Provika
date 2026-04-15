import AVFoundation
import os

@Observable
final class CameraViewModel {

    var isFlashOn = false
    var cameraPermissionGranted = false

    let captureService = CaptureService()

    private let logger = Logger(subsystem: "com.bbdyno.app.provika", category: "CameraVM")

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
        captureService.stopSession()
    }

    private func setupCamera() {
        captureService.configureSession()
        captureService.startSession()
    }
}
