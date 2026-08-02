import CoreLocation
import Foundation
import ImageIO
import UIKit

/// The immutable input obtained at the instant a still photo is captured.
struct PhotoEvidenceCaptureResultV2: Equatable {
    let fileData: Data
    let pixelWidth: Int
    let pixelHeight: Int
    let mediaType: String
    let capturedAt: Date
}

/// Metadata deliberately supplied by the app boundary so package construction is deterministic and testable.
struct PhotoEvidenceCaptureMetadataV2: Equatable {
    let appName: String
    let appVersion: String
    let appBuild: String
    let deviceModel: String
    let systemVersion: String

    static func current(bundle: Bundle = .main, device: UIDevice = .current) -> Self {
        Self(
            appName: bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? "Provika",
            appVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0",
            appBuild: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1",
            deviceModel: device.model,
            systemVersion: "iOS \(device.systemVersion)"
        )
    }
}

enum PhotoEvidenceCapturePipelineErrorV2: Error, Equatable {
    case busy
    case captureFailed
    case malformedPhotoData
    case invalidPhotoDimensions
    case unsupportedMediaType
    case temporaryWriteFailed
    case finalizationFailed
    case verificationFailed(PhotoEvidencePackageVerificationResultV2)
}

enum PhotoEvidenceCapturePipelineResultV2: Equatable {
    case success(packageDirectory: URL, claim: PhotoEvidenceClaimV2)
    case failure(PhotoEvidenceCapturePipelineErrorV2)
}

/// Serializes still-photo publication and publishes a package only after an independent offline verification.
final class PhotoEvidenceCapturePipelineV2 {
    typealias Finalize = (URL, PhotoEvidenceClaimV2, URL) throws -> URL
    typealias Verify = (URL) -> PhotoEvidencePackageVerificationResultV2

    private let rootDirectory: URL
    private let metadata: PhotoEvidenceCaptureMetadataV2
    private let packageIDProvider: () -> UUID
    private let finalizer: Finalize
    private let verifier: Verify
    private let fileManager: FileManager
    private let queue = DispatchQueue(label: "com.bbdyno.app.provika.photo-evidence", qos: .userInitiated)
    private let stateLock = NSLock()
    private var isCapturing = false

    init(
        rootDirectory: URL,
        metadata: PhotoEvidenceCaptureMetadataV2 = .current(),
        packageIDProvider: @escaping () -> UUID = UUID.init,
        finalizer: @escaping Finalize,
        verifier: @escaping Verify,
        fileManager: FileManager = .default
    ) {
        self.rootDirectory = rootDirectory
        self.metadata = metadata
        self.packageIDProvider = packageIDProvider
        self.finalizer = finalizer
        self.verifier = verifier
        self.fileManager = fileManager
    }

    convenience init(
        rootDirectory: URL,
        metadata: PhotoEvidenceCaptureMetadataV2 = .current(),
        packageIDProvider: @escaping () -> UUID = UUID.init,
        finalizer: PhotoEvidencePackageFinalizerV2 = .init(),
        verifier: PhotoEvidencePackageVerifierV2 = .init(),
        fileManager: FileManager = .default
    ) {
        self.init(
            rootDirectory: rootDirectory,
            metadata: metadata,
            packageIDProvider: packageIDProvider,
            finalizer: { try finalizer.finalize(originalPhotoURL: $0, claim: $1, packageDirectory: $2) },
            verifier: { verifier.verify(packageDirectory: $0) },
            fileManager: fileManager
        )
    }

    func capture(
        _ result: PhotoEvidenceCaptureResultV2,
        location: CLLocation?,
        completion: @escaping (PhotoEvidenceCapturePipelineResultV2) -> Void
    ) {
        stateLock.lock()
        let accepted = !isCapturing
        if accepted { isCapturing = true }
        stateLock.unlock()
        guard accepted else {
            completion(.failure(.busy))
            return
        }

        queue.async { [weak self] in
            guard let self else { return }
            let outcome = self.publish(result, location: location)
            self.stateLock.lock()
            self.isCapturing = false
            self.stateLock.unlock()
            DispatchQueue.main.async { completion(outcome) }
        }
    }

    private func publish(_ result: PhotoEvidenceCaptureResultV2, location: CLLocation?) -> PhotoEvidenceCapturePipelineResultV2 {
        guard let sourceDimensions = jpegDimensions(of: result.fileData) else {
            return .failure(.malformedPhotoData)
        }
        guard result.pixelWidth > 0, result.pixelHeight > 0,
              result.pixelWidth == sourceDimensions.width,
              result.pixelHeight == sourceDimensions.height else {
            return .failure(.invalidPhotoDimensions)
        }
        guard result.mediaType == "image/jpeg" else { return .failure(.unsupportedMediaType) }

        let packageID = packageIDProvider()
        let packageDirectory = rootDirectory.appendingPathComponent(packageID.uuidString.lowercased(), isDirectory: true)
        let temporaryPhotoURL = rootDirectory.appendingPathComponent(".\(packageID.uuidString.lowercased()).jpg", isDirectory: false)
        let packageExistedAtStart = fileManager.fileExists(atPath: packageDirectory.path)
        var published = false
        defer {
            try? fileManager.removeItem(at: temporaryPhotoURL)
            if !published, !packageExistedAtStart { try? fileManager.removeItem(at: packageDirectory) }
        }

        do {
            try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
            try result.fileData.write(to: temporaryPhotoURL, options: .atomic)
        } catch {
            return .failure(.temporaryWriteFailed)
        }

        let claim = makeClaim(
            packageID: packageID,
            result: result,
            location: location
        )
        do {
            _ = try finalizer(temporaryPhotoURL, claim, packageDirectory)
        } catch {
            return .failure(.finalizationFailed)
        }

        let verification = verifier(packageDirectory)
        guard verification == .valid else { return .failure(.verificationFailed(verification)) }
        published = true
        return .success(packageDirectory: packageDirectory, claim: claim)
    }

    private func makeClaim(packageID: UUID, result: PhotoEvidenceCaptureResultV2, location: CLLocation?) -> PhotoEvidenceClaimV2 {
        PhotoEvidenceClaimV2(
            packageID: packageID,
            media: .init(fileName: "original.jpg", mediaType: result.mediaType, pixelWidth: result.pixelWidth, pixelHeight: result.pixelHeight, sha256: HashCalculator.sha256(of: result.fileData)),
            capture: .init(deviceTime: Self.iso8601.string(from: result.capturedAt)),
            app: .init(name: metadata.appName, version: metadata.appVersion, build: metadata.appBuild),
            device: .init(model: metadata.deviceModel, systemVersion: metadata.systemVersion),
            location: location.map {
                .init(lat: $0.coordinate.latitude, lng: $0.coordinate.longitude, horizontalAccuracyMeters: $0.horizontalAccuracy, altitudeMeters: $0.verticalAccuracy >= 0 ? $0.altitude : nil, verticalAccuracyMeters: $0.verticalAccuracy >= 0 ? $0.verticalAccuracy : nil, headingDegrees: $0.course >= 0 ? $0.course : nil, speedMetersPerSecond: $0.speed >= 0 ? $0.speed : nil)
            }
        )
    }

    private func jpegDimensions(of data: Data) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) == 1,
              CGImageSourceGetType(source) == "public.jpeg" as CFString,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
              width > 0, height > 0 else { return nil }
        return (width, height)
    }

    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
