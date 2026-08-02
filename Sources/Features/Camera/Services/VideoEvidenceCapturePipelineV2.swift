import Foundation

struct VideoEvidenceCaptureMetadataV2: Equatable, Sendable {
    let appVersion: String
    let appBuild: String
    let deviceModel: String
    let systemVersion: String
}

struct VideoEvidenceCaptureInputV2: Equatable, Sendable {
    let stagedVideoURL: URL
    let capturedAtUTC: String
    let finalizedAtUTC: String
    let audioObservation: VideoAudioPermissionObservation
}

enum VideoEvidenceCapturePipelineErrorV2: Error, Equatable {
    case busy
    case finalizationFailed
    case mediaValidationFailed(VideoEvidenceMediaValidationError)
    case packageFinalizationFailed
    case verificationRejected
}

enum VideoEvidenceCapturePipelineResultV2: Equatable {
    case completed(packageDirectory: URL, derivativeEligible: Bool)
    case failed(VideoEvidenceCapturePipelineErrorV2)
}

/// Ordered transaction: staging -> writer finalization -> playable/track
/// validation -> atomic package move -> hash/claim/signing -> verifier ->
/// derivative eligibility. Failure performs Task-owned staging cleanup; the
/// finalizer owns private-package quarantine cleanup.
final class VideoEvidenceCapturePipelineV2 {
    enum Stage: String, Equatable {
        case stagingPrepared
        case finalizationCompleted
        case playableTrackValidated
        case atomicPackagePublished
        case hashAndClaimBuilt
        case signingCompleted
        case verifierAccepted
        case derivativeEligible
        case cleanupCompleted
    }

    typealias AwaitFinalization = (URL) throws -> URL
    typealias Validate = (URL, VideoAudioPermissionObservation) -> Result<VideoEvidenceMediaObservation, VideoEvidenceMediaValidationError>
    typealias Finalize = (URL, VideoEvidenceClaimV2, URL) throws -> URL
    typealias Verify = (URL) -> Bool

    private let rootDirectory: URL
    private let metadata: VideoEvidenceCaptureMetadataV2
    private let packageIDProvider: () -> UUID
    private let awaitFinalization: AwaitFinalization
    private let validate: Validate
    private let finalize: Finalize
    private let verifier: Verify
    private let fileManager: FileManager
    private let lock = NSLock()
    private var running = false

    private(set) var stageLog: [Stage] = []

    init(
        rootDirectory: URL,
        metadata: VideoEvidenceCaptureMetadataV2,
        packageIDProvider: @escaping () -> UUID = UUID.init,
        awaitFinalization: @escaping AwaitFinalization,
        validate: @escaping Validate,
        finalize: @escaping Finalize,
        verifier: @escaping Verify,
        fileManager: FileManager = .default
    ) {
        self.rootDirectory = rootDirectory
        self.metadata = metadata
        self.packageIDProvider = packageIDProvider
        self.awaitFinalization = awaitFinalization
        self.validate = validate
        self.finalize = finalize
        self.verifier = verifier
        self.fileManager = fileManager
    }

    @discardableResult
    func publish(_ input: VideoEvidenceCaptureInputV2) -> VideoEvidenceCapturePipelineResultV2 {
        lock.lock()
        guard !running else { lock.unlock(); return .failed(.busy) }
        running = true
        stageLog = [.stagingPrepared]
        lock.unlock()
        defer { lock.withLock { running = false } }

        let packageID = packageIDProvider()
        let destination = rootDirectory.appendingPathComponent(packageID.uuidString.lowercased(), isDirectory: true)
        let destinationExisted = fileManager.fileExists(atPath: destination.path)
        var finalizedURL = input.stagedVideoURL
        var published = false
        defer {
            try? fileManager.removeItem(at: input.stagedVideoURL)
            if finalizedURL != input.stagedVideoURL { try? fileManager.removeItem(at: finalizedURL) }
            if !published, !destinationExisted { try? fileManager.removeItem(at: destination) }
            stageLog.append(.cleanupCompleted)
        }

        do {
            try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
            finalizedURL = try awaitFinalization(input.stagedVideoURL)
            stageLog.append(.finalizationCompleted)
        } catch {
            return .failed(.finalizationFailed)
        }

        let observation: VideoEvidenceMediaObservation
        switch validate(finalizedURL, input.audioObservation) {
        case let .success(value): observation = value
        case let .failure(error): return .failed(.mediaValidationFailed(error))
        }
        guard observation.playable else { return .failed(.mediaValidationFailed(.notPlayable)) }
        stageLog.append(.playableTrackValidated)

        let claim = VideoEvidenceClaimV2(
            packageID: packageID,
            media: .init(fileName: VideoEvidenceClaimV2.originalFileName, mediaType: "video/quicktime", byteLength: 0, sha256: String(repeating: "0", count: 64)),
            capture: .init(deviceTimeUTC: input.capturedAtUTC),
            app: .init(name: "Provika", version: metadata.appVersion, build: metadata.appBuild),
            device: .init(model: metadata.deviceModel, systemVersion: metadata.systemVersion),
            finalization: .init(completedAtUTC: input.finalizedAtUTC),
            videoTrack: observation.videoTrack,
            audioTrack: observation.audioTrack,
            audioIncluded: input.audioObservation.audioIncluded,
            microphoneAuthorization: input.audioObservation.microphoneAuthorization,
            silentRecordingDecision: input.audioObservation.silentRecordingDecision
        )
        do {
            _ = try finalize(finalizedURL, claim, destination)
            stageLog.append(.atomicPackagePublished)
            stageLog.append(.hashAndClaimBuilt)
            stageLog.append(.signingCompleted)
        } catch {
            return .failed(.packageFinalizationFailed)
        }

        guard verifier(destination) else { return .failed(.verificationRejected) }
        stageLog.append(.verifierAccepted)
        stageLog.append(.derivativeEligible)
        published = true
        return .completed(packageDirectory: destination, derivativeEligible: true)
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
