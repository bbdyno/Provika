import AVFoundation
import os

@Observable
final class CaptureService {

    let session = AVCaptureSession()
    var isSessionRunning = false
    var currentZoomFactor: CGFloat = 1.0
    var minZoomFactor: CGFloat = 1.0
    var maxZoomFactor: CGFloat = 5.0

    private var videoDeviceInput: AVCaptureDeviceInput?
    private let sessionQueue = DispatchQueue(label: "com.bbdyno.app.provika.capture")
    private let logger = Logger(subsystem: "com.bbdyno.app.provika", category: "Capture")

    func configureSession() {
        sessionQueue.async { [weak self] in
            self?.setupSession()
        }
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self, !session.isRunning else { return }
            session.startRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = self.session.isRunning
            }
            logger.info("캡처 세션 시작")
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self, session.isRunning else { return }
            session.stopRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = self.session.isRunning
            }
            logger.info("캡처 세션 중지")
        }
    }

    func setZoom(_ factor: CGFloat) {
        guard let device = videoDeviceInput?.device else { return }
        let clamped = min(max(factor, minZoomFactor), maxZoomFactor)

        do {
            try device.lockForConfiguration()
            device.ramp(toVideoZoomFactor: clamped, withRate: 8.0)
            device.unlockForConfiguration()
            DispatchQueue.main.async {
                self.currentZoomFactor = clamped
            }
        } catch {
            logger.error("줌 설정 실패: \(error.localizedDescription)")
        }
    }

    func focusAndExpose(at point: CGPoint) {
        guard let device = videoDeviceInput?.device else { return }

        do {
            try device.lockForConfiguration()

            if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
            }

            if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.autoExpose) {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
            }

            device.unlockForConfiguration()

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.resetFocusAndExposure(device: device)
            }
        } catch {
            logger.error("포커스/노출 설정 실패: \(error.localizedDescription)")
        }
    }

    func toggleFlash() -> Bool {
        guard let device = videoDeviceInput?.device, device.hasTorch else { return false }
        do {
            try device.lockForConfiguration()
            device.torchMode = device.torchMode == .on ? .off : .on
            device.unlockForConfiguration()
            return device.torchMode == .on
        } catch {
            logger.error("플래시 토글 실패: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Private

    private func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .hd1920x1080

        // 비디오 입력
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            logger.error("후면 카메라를 찾을 수 없음")
            session.commitConfiguration()
            return
        }

        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
                videoDeviceInput = videoInput
            }
        } catch {
            logger.error("비디오 입력 추가 실패: \(error.localizedDescription)")
            session.commitConfiguration()
            return
        }

        // 오디오 입력
        if let audioDevice = AVCaptureDevice.default(for: .audio) {
            do {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if session.canAddInput(audioInput) {
                    session.addInput(audioInput)
                }
            } catch {
                logger.warning("오디오 입력 추가 실패: \(error.localizedDescription)")
            }
        }

        // 줌 범위 설정
        DispatchQueue.main.async { [weak self] in
            guard let self, let device = videoDeviceInput?.device else { return }
            self.minZoomFactor = device.minAvailableVideoZoomFactor
            self.maxZoomFactor = min(device.maxAvailableVideoZoomFactor, 10.0)
        }

        // 안정화 설정
        if let connection = session.connections.first(where: { $0.output is AVCaptureVideoDataOutput || $0.inputPorts.contains(where: { $0.mediaType == .video }) }) {
            if connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = .cinematic
            }
        }

        // 자동 포커스/노출
        if let device = videoDeviceInput?.device {
            do {
                try device.lockForConfiguration()
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
                device.unlockForConfiguration()
            } catch {
                logger.warning("자동 포커스/노출 설정 실패: \(error.localizedDescription)")
            }
        }

        session.commitConfiguration()
        logger.info("캡처 세션 구성 완료")
    }

    private func resetFocusAndExposure(device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            device.unlockForConfiguration()
        } catch {
            logger.warning("포커스/노출 리셋 실패: \(error.localizedDescription)")
        }
    }
}
