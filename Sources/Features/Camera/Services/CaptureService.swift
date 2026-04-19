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
    // UI 1.0x에 해당하는 디바이스 zoomFactor — 가상 카메라(triple/dualWide)에서는 2.0.
    // 실제 사용자 노출 배율 = device.videoZoomFactor / displayZoomDivisor
    var displayZoomDivisor: CGFloat = 1.0

    var currentDisplayZoom: CGFloat { currentZoomFactor / displayZoomDivisor }
    var minDisplayZoom: CGFloat { minZoomFactor / displayZoomDivisor }
    var maxDisplayZoom: CGFloat { maxZoomFactor / displayZoomDivisor }
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
    // 캡처 파이프라인은 항상 포트레이트(90°) 고정. 방향 처리는 OverlayRenderer에서 CoreImage로 수행.
    // 녹화 중에는 이 값이 잠겨 끝까지 유지된다.
    private var recordingOrientation: CGImagePropertyOrientation = .up
    private var latestVideoDimensions = CMVideoDimensions(width: 1080, height: 1920)
    private var recordedVideoDimensions = CMVideoDimensions(width: 1080, height: 1920)

    deinit {
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }

    func attachPreviewLayer(_ previewLayer: AVCaptureVideoPreviewLayer) {
        self.previewLayer = previewLayer
        lockPreviewToPortrait()
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

        // 녹화 시작 순간의 기기 방향으로 결과물 orientation 결정 — 이 한 번의 스냅샷만 사용.
        // 이후 기기가 회전해도 이 값은 바뀌지 않는다. 파이프라인도 건드리지 않아 hiccup 없음.
        let deviceOrientation = UIDevice.current.orientation.isValidInterfaceOrientation
            ? UIDevice.current.orientation
            : .portrait
        let orientation = imageOrientation(for: deviceOrientation)
        recordingOrientation = orientation

        let now = Date()
        let videoURL = FileStorage.generateFileURL(for: now, extension: "mov")
        let recordingDimensions = rotatedDimensions(of: latestVideoDimensions, for: orientation)
        recordedVideoDimensions = recordingDimensions

        let isPortraitRecording = (orientation == .up)

        writerQueue.async { [weak self] in
            guard let self else { return }
            do {
                try videoWriter.startWriting(
                    to: videoURL,
                    width: Int(recordingDimensions.width),
                    height: Int(recordingDimensions.height),
                    codec: .hevc
                )

                // 선녹화 버퍼는 포트레이트로만 렌더되어 있어 가로 녹화엔 크기가 안 맞는다.
                // 가로 녹화일 땐 버퍼를 버리고 현재 프레임부터 시작한다.
                if isPortraitRecording {
                    let buffered = preRecordBuffer.flush()
                    for frame in buffered.video {
                        videoWriter.appendVideoBuffer(frame.pixelBuffer, at: frame.time)
                    }
                    for audioBuffer in buffered.audio {
                        videoWriter.appendAudioBuffer(audioBuffer)
                    }
                } else {
                    preRecordBuffer.clear()
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
                logger.error("녹화 시작 실패: \(error.localizedDescription)")
            }
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        let finalDuration = elapsedTime
        recordingOrientation = .up

        DispatchQueue.main.async { [weak self] in
            self?.stopTimer()
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

    // UI 노출 배율(0.5x ~ 5.0x 등)로 줌 설정. 내부적으로 divisor를 곱해 device zoom으로 변환.
    func setDisplayZoom(_ display: CGFloat) {
        setZoom(display * displayZoomDivisor)
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

    // 후면 카메라 선택: 0.5x 지원을 위해 triple → dualWide → wideAngle 순으로 폴백
    private func selectBackCameraDevice() -> AVCaptureDevice? {
        if let triple = AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: .back) {
            return triple
        }
        if let dualWide = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back) {
            return dualWide
        }
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    }

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

        // 비디오 입력 — 0.5x(울트라와이드) 지원을 위해 가상 카메라 우선 선택
        guard let videoDevice = selectBackCameraDevice() else {
            logger.error("후면 카메라를 찾을 수 없음")
            session.commitConfiguration()
            return
        }

        // 가상 카메라(triple/dualWide)는 내부 zoomFactor 1.0이 울트라와이드(UI 0.5x).
        // switchOver 첫 값(통상 2.0)이 wide 렌즈 경계 = UI 1.0x.
        let divisor: CGFloat = {
            switch videoDevice.deviceType {
            case .builtInTripleCamera, .builtInDualWideCamera:
                return videoDevice.virtualDeviceSwitchOverVideoZoomFactors.first?.doubleValue ?? 2.0
            default:
                return 1.0
            }
        }()

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

        // 초기 줌을 UI 1.0x(= wide 렌즈)로 맞춘다
        do {
            try videoDevice.lockForConfiguration()
            videoDevice.videoZoomFactor = max(divisor, videoDevice.minAvailableVideoZoomFactor)
            videoDevice.unlockForConfiguration()
        } catch {
            logger.warning("초기 줌 설정 실패: \(error.localizedDescription)")
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

        // 비디오 데이터 출력은 영원히 포트레이트(90°) 고정. 파이프라인을 재구성하면 hiccup이 생기므로
        // 회전 처리는 OverlayRenderer에서 CIImage로 수행한다.
        if let connection = vOutput.connection(with: .video),
           connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
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
            self.displayZoomDivisor = divisor
            self.minZoomFactor = device.minAvailableVideoZoomFactor
            self.maxZoomFactor = min(device.maxAvailableVideoZoomFactor, divisor * 5.0)
            self.currentZoomFactor = device.videoZoomFactor
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
            self?.lockPreviewToPortrait()
        }
        logger.info("캡처 세션 구성 완료")
    }

    // 회전 알림 구독 없이 UIDevice.current.orientation만 유효하게 한다.
    // 알림마다 캡처 회전을 건드리면 AVCapture 파이프라인이 재구성되며 프리뷰가 멈칫거리므로
    // 회전은 녹화 시작 순간에만 결정한다.
    private func startObservingOrientationChangesIfNeeded() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    }

    // 프리뷰 connection은 세션 구성이 끝나야 형성되므로, attach·session 구성 후에 재적용한다.
    private func lockPreviewToPortrait() {
        guard let connection = previewLayer?.connection,
              connection.isVideoRotationAngleSupported(90) else { return }
        if connection.videoRotationAngle != 90 {
            connection.videoRotationAngle = 90
        }
    }

    // UIDeviceOrientation → CIImage 회전용 EXIF orientation.
    // 포트레이트 프레임을 해당 orientation으로 회전시키면 "하늘이 위"인 올바른 출력이 된다.
    private func imageOrientation(for orientation: UIDeviceOrientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .portrait:
            return .up
        case .portraitUpsideDown:
            return .down
        case .landscapeLeft:
            return .right
        case .landscapeRight:
            return .left
        default:
            return .up
        }
    }

    // 회전 적용 시 W/H가 바뀌는지 여부에 따라 출력 프레임 크기를 계산.
    private func rotatedDimensions(
        of base: CMVideoDimensions,
        for orientation: CGImagePropertyOrientation
    ) -> CMVideoDimensions {
        let width = base.width > 0 ? base.width : 1080
        let height = base.height > 0 ? base.height : 1920
        let swapWH = (orientation == .left || orientation == .right
            || orientation == .leftMirrored || orientation == .rightMirrored)
        return swapWH
            ? CMVideoDimensions(width: height, height: width)
            : CMVideoDimensions(width: width, height: height)
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

            // 캡처는 항상 포트레이트 — 인입 프레임은 포트레이트 크기(1080x1920 등).
            if !isRecording {
                latestVideoDimensions = CMVideoDimensions(
                    width: Int32(CVPixelBufferGetWidth(pixelBuffer)),
                    height: Int32(CVPixelBufferGetHeight(pixelBuffer))
                )
            }

            // 녹화·선녹화 모두 꺼져 있으면 오버레이 렌더 생략 (프리뷰는 별도 레이어)
            let preRecordEnabled = preRecordBuffer.isEnabled
            guard isRecording || preRecordEnabled else { return }

            // 녹화 중엔 녹화 시작 시점의 orientation 고정. 선녹화 버퍼는 포트레이트(.up)로만 저장.
            let orientation: CGImagePropertyOrientation = isRecording ? recordingOrientation : .up

            let currentLocation = locationManager?.currentLocation
            guard let renderedBuffer = overlayRenderer.render(
                pixelBuffer: pixelBuffer,
                location: currentLocation,
                deviceInfo: cachedDeviceInfo,
                orientation: orientation
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
