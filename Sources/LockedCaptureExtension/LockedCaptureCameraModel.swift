import AVFoundation
import Foundation
import os

// 잠금 상태 촬영용 캡처 세션.
// 여기서 만든 미디어는 서명 전 인계분이다. 봉인은 잠금 해제 후 부모 앱만 수행한다.
@Observable
final class LockedCaptureCameraModel: NSObject {
    enum Status: Equatable {
        case ready
        case recording
        case saved
        case failed
        case cameraUnavailable
    }

    let session = AVCaptureSession()
    private(set) var status: Status = .ready
    private(set) var isRecording = false

    private let sessionContentURL: URL
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let sessionQueue = DispatchQueue(label: "com.bbdyno.app.provika.locked-capture")
    private let logger = Logger(subsystem: "com.bbdyno.app.provika.locked-capture", category: "Capture")
    private var configured = false
    private var photoCapturedAt: Date?
    private var recordingStartedAt: Date?

    init(sessionContentURL: URL) {
        self.sessionContentURL = sessionContentURL
    }

    func start() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !configured {
                configured = configure()
            }
            guard configured else {
                publish(status: .cameraUnavailable)
                return
            }
            if !session.isRunning {
                session.startRunning()
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            // 화면이 닫혀도 찍던 영상은 인계분으로 남긴다.
            if movieOutput.isRecording {
                movieOutput.stopRecording()
            }
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    func capturePhoto() {
        sessionQueue.async { [weak self] in
            guard let self, configured, session.isRunning, photoCapturedAt == nil else { return }
            photoCapturedAt = Date()
            let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func toggleRecording() {
        sessionQueue.async { [weak self] in
            guard let self, configured, session.isRunning else { return }
            if movieOutput.isRecording {
                movieOutput.stopRecording()
                return
            }
            // 숨김 이름으로 녹화해 두면 부모 앱의 가져오기가 완성 전 파일을 보지 않는다.
            let url = sessionContentURL.appendingPathComponent(".recording-\(UUID().uuidString).mov")
            recordingStartedAt = Date()
            movieOutput.startRecording(to: url, recordingDelegate: self)
        }
    }

    // MARK: - Private

    private func configure() -> Bool {
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let cameraInput = try? AVCaptureDeviceInput(device: camera) else {
            return false
        }

        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .hd1920x1080

        guard session.canAddInput(cameraInput) else { return false }
        session.addInput(cameraInput)

        // 마이크를 쓸 수 없으면 소리 없이 영상만 남긴다.
        if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized,
           let microphone = AVCaptureDevice.default(for: .audio),
           let microphoneInput = try? AVCaptureDeviceInput(device: microphone),
           session.canAddInput(microphoneInput) {
            session.addInput(microphoneInput)
        }

        guard session.canAddOutput(photoOutput), session.canAddOutput(movieOutput) else { return false }
        session.addOutput(photoOutput)
        session.addOutput(movieOutput)
        // 인계 한도를 넘는 파일은 부모 앱이 받지 않으므로 그 전에 녹화를 끝낸다.
        movieOutput.maxRecordedFileSize = Int64(LockedCapturePendingHandoffWriter.maximumBytes)

        for output in [photoOutput, movieOutput] as [AVCaptureOutput] {
            if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        }
        if let connection = movieOutput.connection(with: .video),
           movieOutput.availableVideoCodecTypes.contains(.hevc) {
            movieOutput.setOutputSettings([AVVideoCodecKey: AVVideoCodecType.hevc], for: connection)
        }
        return true
    }

    private func publish(status: Status, isRecording: Bool = false) {
        DispatchQueue.main.async { [weak self] in
            self?.status = status
            self?.isRecording = isRecording
        }
    }
}

extension LockedCaptureCameraModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let capturedAt = photoCapturedAt
            photoCapturedAt = nil
            let keepRecording = movieOutput.isRecording
            // 카메라가 낸 원본 JPEG 바이트를 그대로 넘긴다. 다시 인코딩하지 않는다.
            guard error == nil, let capturedAt, let data = photo.fileDataRepresentation() else {
                publish(status: .failed, isRecording: keepRecording)
                return
            }
            do {
                _ = try LockedCapturePendingHandoffWriter.publish(
                    mediaData: data,
                    fileExtension: "jpg",
                    mediaType: "image/jpeg",
                    capturedAt: capturedAt,
                    to: sessionContentURL
                )
                publish(status: keepRecording ? .recording : .saved, isRecording: keepRecording)
            } catch {
                logger.error("사진 인계 실패: \(error.localizedDescription)")
                publish(status: .failed, isRecording: keepRecording)
            }
        }
    }
}

extension LockedCaptureCameraModel: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        publish(status: .recording, isRecording: true)
    }

    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let startedAt = recordingStartedAt
            recordingStartedAt = nil
            // 용량 한도·인터럽션으로 끝났어도 파일이 온전히 닫혔으면 그대로 넘긴다.
            let finished = error == nil
                || ((error as NSError?)?.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool) == true
            guard finished, let startedAt else {
                try? FileManager.default.removeItem(at: outputFileURL)
                publish(status: .failed)
                return
            }
            do {
                _ = try LockedCapturePendingHandoffWriter.publish(
                    mediaFileAt: outputFileURL,
                    fileExtension: "mov",
                    mediaType: "video/quicktime",
                    capturedAt: startedAt,
                    to: sessionContentURL
                )
                publish(status: .saved)
            } catch {
                logger.error("영상 인계 실패: \(error.localizedDescription)")
                try? FileManager.default.removeItem(at: outputFileURL)
                publish(status: .failed)
            }
        }
    }
}
