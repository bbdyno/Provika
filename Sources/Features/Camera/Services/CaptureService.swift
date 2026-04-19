//
//  CaptureService.swift
//  Provika
//
//  Created by bbdyno on 4/16/26.
//

import AVFoundation
import CoreLocation
import UIKit
import os

@Observable
final class CaptureService: NSObject {

    let session = AVCaptureSession()
    var isSessionRunning = false
    var isRecording = false
    var currentZoomFactor: CGFloat = 1.0
    var minZoomFactor: CGFloat = 1.0
    var maxZoomFactor: CGFloat = 5.0
    var recordingStartTime: Date?
    var elapsedTime: TimeInterval = 0

    // 콜백 시그니처: (영상 URL, 사이드카 URL, duration, SHA-256 해시)
    var onRecordingFinished: ((URL, URL, TimeInterval, String) -> Void)?

    // 위치 데이터는 LocationManager에서 직접 읽는다 (VM 폴링 제거)
    weak var locationManager: LocationManager?

    private var videoDeviceInput: AVCaptureDeviceInput?
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var audioDataOutput: AVCaptureAudioDataOutput?

    private let sessionQueue = DispatchQueue(label: "com.bbdyno.app.provika.capture")
    private let writerQueue = DispatchQueue(label: "com.bbdyno.app.provika.writer")
    private let logger = Logger(subsystem: "com.bbdyno.app.provika", category: "Capture")

    private let videoWriter = VideoWriter()
    private let overlayRenderer = OverlayRenderer()
    private let signatureService = SignatureService()
    let preRecordBuffer = PreRecordBuffer()

    private var cachedDeviceInfo = OverlayRenderer.DeviceInfo(model: "iPhone", appVersion: "1.0.0")
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private var locationTrack: [RecordingMetadata.LocationPoint] = []
    private var lastLocationTrackTime: Date?
    private var recordingTimer: Timer?
    private weak var previewLayer: AVCaptureVideoPreviewLayer?
    private var orientationObserver: NSObjectProtocol?
    private var currentPreviewRotationAngle: CGFloat = 90
    private var currentCaptureRotationAngle: CGFloat = 90
    private var recordingStartRotationAngle: CGFloat = 90
    private var latestVideoDimensions = CMVideoDimensions(width: 1080, height: 1920)
    private var recordedVideoDimensions = CMVideoDimensions(width: 1080, height: 1920)
    private var isRotationLocked = false

    deinit {
        if let orientationObserver {
            NotificationCenter.default.removeObserver(orientationObserver)
        }
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }

    func attachPreviewLayer(_ previewLayer: AVCaptureVideoPreviewLayer) {
        self.previewLayer = previewLayer
        applyCurrentOrientation(clearBuffer: false)
    }

    func configureSession() {
        // 설정에서 선녹화 버퍼 길이 반영
        let preRecordSeconds = UserDefaults.standard.integer(forKey: "preRecordDuration")
        preRecordBuffer.updateDuration(TimeInterval(preRecordSeconds))

        // UIDevice.current.name은 메인 스레드 전용 — 한 번만 캐싱해서 writerQueue에서 안전하게 사용
        cachedDeviceInfo = OverlayRenderer.DeviceInfo(
            model: UIDevice.current.name,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        )

        startObservingOrientationChangesIfNeeded()

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

    func startRecording() {
        guard !isRecording else { return }

        let now = Date()
        let videoURL = FileStorage.generateFileURL(for: now, extension: "mov")
        let recordingDimensions = currentRecordingDimensions()

        isRotationLocked = true
        recordingStartRotationAngle = currentCaptureRotationAngle
        recordedVideoDimensions = recordingDimensions

        writerQueue.async { [weak self] in
            guard let self else { return }
            do {
                try videoWriter.startWriting(
                    to: videoURL,
                    width: Int(recordingDimensions.width),
                    height: Int(recordingDimensions.height),
                    codec: .hevc
                )

                // 선녹화 버퍼 플러시
                let buffered = preRecordBuffer.flush()
                for frame in buffered.video {
                    videoWriter.appendVideoBuffer(frame.pixelBuffer, at: frame.time)
                }
                for audioBuffer in buffered.audio {
                    videoWriter.appendAudioBuffer(audioBuffer)
                }

                isRecording = true
                recordingStartTime = now
                elapsedTime = 0
                locationTrack = []
                lastLocationTrackTime = nil

                DispatchQueue.main.async { [weak self] in
                    self?.startTimer()
                }

                logger.info("녹화 시작: \(videoURL.lastPathComponent)")
            } catch {
                isRotationLocked = false
                logger.error("녹화 시작 실패: \(error.localizedDescription)")
            }
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        let finalDuration = elapsedTime
        isRotationLocked = false

        DispatchQueue.main.async { [weak self] in
            self?.stopTimer()
            // 녹화 도중 방향이 바뀌지 않았다면 세션 재설정 생략
            guard let self else { return }
            let currentAngle = self.currentCaptureRotationAngle
            if currentAngle != self.recordingStartRotationAngle {
                self.applyPreviewRotation(currentAngle)
                self.applyCaptureRotation(currentAngle, clearBuffer: true)
            }
        }

        Task { [weak self] in
            guard let self else { return }
            guard let videoURL = await videoWriter.finishWriting() else {
                logger.error("비디오 파일 저장 실패")
                return
            }

            let sidecarURL = videoURL.deletingPathExtension().appendingPathExtension("json")
            // 해시는 한 번만 계산해 사이드카와 콜백에 재사용
            let hash = (try? HashCalculator.sha256(of: videoURL)) ?? ""
            await saveSidecarJSON(videoURL: videoURL, sidecarURL: sidecarURL, hash: hash)

            await MainActor.run {
                self.onRecordingFinished?(videoURL, sidecarURL, finalDuration, hash)
                self.recordingStartTime = nil
                self.elapsedTime = 0
            }
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

        // 기존 입출력 제거 (중복 방지)
        for input in session.inputs {
            session.removeInput(input)
        }
        for output in session.outputs {
            session.removeOutput(output)
        }

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

        // 비디오 데이터 출력
        let vOutput = AVCaptureVideoDataOutput()
        vOutput.setSampleBufferDelegate(self, queue: writerQueue)
        vOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        vOutput.alwaysDiscardsLateVideoFrames = true

        if session.canAddOutput(vOutput) {
            session.addOutput(vOutput)
            videoDataOutput = vOutput
        }

        // 오디오 데이터 출력
        let aOutput = AVCaptureAudioDataOutput()
        aOutput.setSampleBufferDelegate(self, queue: writerQueue)

        if session.canAddOutput(aOutput) {
            session.addOutput(aOutput)
            audioDataOutput = aOutput
        }

        // 줌 범위 설정
        DispatchQueue.main.async { [weak self] in
            guard let self, let device = videoDeviceInput?.device else { return }
            self.minZoomFactor = device.minAvailableVideoZoomFactor
            self.maxZoomFactor = min(device.maxAvailableVideoZoomFactor, 10.0)
        }

        // 안정화
        if let connection = vOutput.connection(with: .video) {
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
        DispatchQueue.main.async { [weak self] in
            self?.applyCurrentOrientation(clearBuffer: false)
        }
        logger.info("캡처 세션 구성 완료")
    }

    private func startObservingOrientationChangesIfNeeded() {
        guard orientationObserver == nil else { return }

        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyCurrentOrientation(clearBuffer: true)
        }

        DispatchQueue.main.async { [weak self] in
            self?.applyCurrentOrientation(clearBuffer: false)
        }
    }

    private func applyCurrentOrientation(clearBuffer: Bool) {
        guard let angle = captureRotationAngle(for: UIDevice.current.orientation) ?? fallbackCaptureAngle() else {
            return
        }

        let changed = angle != currentCaptureRotationAngle
        currentPreviewRotationAngle = angle
        currentCaptureRotationAngle = angle
        applyPreviewRotation(angle)
        applyCaptureRotation(angle, clearBuffer: clearBuffer && changed)
    }

    private func applyPreviewRotation(_ angle: CGFloat) {
        guard !isRotationLocked,
              let connection = previewLayer?.connection,
              connection.isVideoRotationAngleSupported(angle) else { return }

        connection.videoRotationAngle = angle
    }

    private func applyCaptureRotation(_ angle: CGFloat, clearBuffer: Bool) {
        guard !isRotationLocked else { return }

        sessionQueue.async { [weak self] in
            guard let self,
                  let connection = self.videoDataOutput?.connection(with: .video),
                  connection.isVideoRotationAngleSupported(angle) else { return }
            connection.videoRotationAngle = angle
        }

        guard clearBuffer else { return }
        writerQueue.async { [weak self] in
            self?.preRecordBuffer.clear()
            self?.overlayRenderer.invalidateCaches()
        }
    }

    private func captureRotationAngle(for orientation: UIDeviceOrientation) -> CGFloat? {
        switch orientation {
        case .portrait:
            return 90
        case .portraitUpsideDown:
            return 270
        case .landscapeLeft:
            return 0
        case .landscapeRight:
            return 180
        default:
            return nil
        }
    }

    private func fallbackCaptureAngle() -> CGFloat? {
        if currentCaptureRotationAngle >= 0 {
            return currentCaptureRotationAngle
        }
        return 90
    }

    private func currentRecordingDimensions() -> CMVideoDimensions {
        guard latestVideoDimensions.width > 0, latestVideoDimensions.height > 0 else {
            return defaultVideoDimensions(for: currentCaptureRotationAngle)
        }

        return latestVideoDimensions
    }

    private func defaultVideoDimensions(for angle: CGFloat) -> CMVideoDimensions {
        let isPortrait = Int(angle.rounded()) % 180 != 0
        return isPortrait
            ? CMVideoDimensions(width: 1080, height: 1920)
            : CMVideoDimensions(width: 1920, height: 1080)
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

    private func startTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, let start = recordingStartTime else { return }
            self.elapsedTime = Date().timeIntervalSince(start)
        }
    }

    private func stopTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    private func saveSidecarJSON(videoURL: URL, sidecarURL: URL, hash: String) async {
        let model = await MainActor.run { UIDevice.current.name }
        let systemVersion = await MainActor.run { UIDevice.current.systemVersion }
        let vendorId = await MainActor.run { UIDevice.current.identifierForVendor?.uuidString }

        let device = RecordingMetadata.DeviceInfo(
            model: model,
            systemVersion: "iOS \(systemVersion)",
            identifierForVendor: vendorId
        )

        let startDate = recordingStartTime ?? Date()
        let id = videoURL.deletingPathExtension().lastPathComponent

        var metadata = RecordingMetadata.create(
            id: id,
            device: device,
            resolution: "\(recordedVideoDimensions.width)x\(recordedVideoDimensions.height)",
            frameRate: 30,
            codec: "hevc",
            startedAt: startDate
        )
        metadata.locationTrack = locationTrack

        if !hash.isEmpty {
            logger.info("SHA-256 해시: \(hash)")
            do {
                let hashData = Data(hash.utf8)
                let signature = try signatureService.sign(data: hashData)
                let publicKeyPEM = try signatureService.publicKeyPEM()

                metadata.integrity = RecordingMetadata.IntegrityInfo(
                    algorithm: "SHA-256",
                    hash: hash,
                    signatureAlgorithm: "ECDSA-P256-SHA256",
                    signature: signature.base64EncodedString(),
                    publicKey: publicKeyPEM
                )
            } catch {
                logger.error("서명 실패: \(error.localizedDescription)")
                metadata.integrity = RecordingMetadata.IntegrityInfo(
                    algorithm: "SHA-256",
                    hash: hash,
                    signatureAlgorithm: nil,
                    signature: nil,
                    publicKey: nil
                )
            }
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let data = try encoder.encode(metadata)
            try data.write(to: sidecarURL)
            logger.info("사이드카 JSON 저장: \(sidecarURL.lastPathComponent)")
        } catch {
            logger.error("사이드카 JSON 저장 실패: \(error.localizedDescription)")
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate & AVCaptureAudioDataOutputSampleBufferDelegate

extension CaptureService: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        if output is AVCaptureVideoDataOutput {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

            if !isRotationLocked {
                latestVideoDimensions = CMVideoDimensions(
                    width: Int32(CVPixelBufferGetWidth(pixelBuffer)),
                    height: Int32(CVPixelBufferGetHeight(pixelBuffer))
                )
            }

            // 녹화·선녹화 모두 꺼져 있으면 오버레이 렌더 생략 (프리뷰는 별도 레이어)
            let preRecordEnabled = preRecordBuffer.isEnabled
            guard isRecording || preRecordEnabled else { return }

            let currentLocation = locationManager?.currentLocation
            guard let renderedBuffer = overlayRenderer.render(
                pixelBuffer: pixelBuffer,
                location: currentLocation,
                deviceInfo: cachedDeviceInfo
            ) else { return }

            if isRecording {
                appendLocationTrackIfNeeded(location: currentLocation)
                let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                videoWriter.appendVideoBuffer(renderedBuffer, at: presentationTime)
            } else {
                let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                preRecordBuffer.appendVideo(time: time, renderedBuffer: renderedBuffer)
            }
        } else if output is AVCaptureAudioDataOutput {
            if isRecording {
                videoWriter.appendAudioBuffer(sampleBuffer)
            } else if preRecordBuffer.isEnabled {
                preRecordBuffer.appendAudio(sampleBuffer: sampleBuffer)
            }
        }
    }

    private func appendLocationTrackIfNeeded(location: CLLocation?) {
        guard let loc = location else { return }
        let now = Date()
        if let last = lastLocationTrackTime, now.timeIntervalSince(last) < 1.0 {
            return
        }
        lastLocationTrackTime = now

        let point = RecordingMetadata.LocationPoint(
            ts: Self.isoFormatter.string(from: now),
            lat: loc.coordinate.latitude,
            lng: loc.coordinate.longitude,
            speed: max(0, loc.speed * 3.6),
            heading: max(0, loc.course)
        )
        locationTrack.append(point)
    }
}
