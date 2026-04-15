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

    var onRecordingFinished: ((URL, URL) -> Void)?

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

    var currentLocation: CLLocation?
    private var locationTrack: [RecordingMetadata.LocationPoint] = []
    private var recordingTimer: Timer?

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

    func startRecording() {
        guard !isRecording else { return }

        let now = Date()
        let videoURL = FileStorage.generateFileURL(for: now, extension: "mov")

        writerQueue.async { [weak self] in
            guard let self else { return }
            do {
                try videoWriter.startWriting(
                    to: videoURL,
                    width: 1920,
                    height: 1080,
                    codec: .hevc
                )

                // 선녹화 버퍼 플러시
                let buffered = preRecordBuffer.flush()
                for (sampleBuffer, renderedBuffer) in buffered.video {
                    let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                    videoWriter.appendVideoBuffer(renderedBuffer, at: time)
                }
                for audioBuffer in buffered.audio {
                    videoWriter.appendAudioBuffer(audioBuffer)
                }

                isRecording = true
                recordingStartTime = now
                elapsedTime = 0
                locationTrack = []

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
            await saveSidecarJSON(videoURL: videoURL, sidecarURL: sidecarURL)

            await MainActor.run {
                self.recordingStartTime = nil
                self.elapsedTime = 0
                self.onRecordingFinished?(videoURL, sidecarURL)
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

    private func deviceInfo() -> OverlayRenderer.DeviceInfo {
        let model = UIDevice.current.name
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        return OverlayRenderer.DeviceInfo(model: model, appVersion: appVersion)
    }

    private func saveSidecarJSON(videoURL: URL, sidecarURL: URL) async {
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
            resolution: "1920x1080",
            frameRate: 30,
            codec: "hevc",
            startedAt: startDate
        )
        metadata.locationTrack = locationTrack

        // 해시 계산
        do {
            let hash = try HashCalculator.sha256(of: videoURL)
            logger.info("SHA-256 해시: \(hash)")

            // 서명
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
            logger.error("무결성 정보 생성 실패: \(error.localizedDescription)")
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

            // 오버레이 렌더링 (녹화/선녹화 공통)
            guard let renderedBuffer = overlayRenderer.render(
                pixelBuffer: pixelBuffer,
                location: currentLocation,
                deviceInfo: deviceInfo()
            ) else { return }

            if isRecording {
                // 위치 트랙 업데이트
                if let loc = currentLocation {
                    let isoFormatter = ISO8601DateFormatter()
                    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

                    let point = RecordingMetadata.LocationPoint(
                        ts: isoFormatter.string(from: Date()),
                        lat: loc.coordinate.latitude,
                        lng: loc.coordinate.longitude,
                        speed: max(0, loc.speed * 3.6),
                        heading: max(0, loc.course)
                    )
                    locationTrack.append(point)
                }

                let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                videoWriter.appendVideoBuffer(renderedBuffer, at: presentationTime)
            } else {
                // 선녹화 버퍼에 저장
                preRecordBuffer.appendVideo(sampleBuffer: sampleBuffer, renderedBuffer: renderedBuffer)
            }
        } else if output is AVCaptureAudioDataOutput {
            if isRecording {
                videoWriter.appendAudioBuffer(sampleBuffer)
            } else {
                preRecordBuffer.appendAudio(sampleBuffer: sampleBuffer)
            }
        }
    }
}
