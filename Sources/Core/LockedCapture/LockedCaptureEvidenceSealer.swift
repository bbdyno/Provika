//
//  LockedCaptureEvidenceSealer.swift
//  Provika
//

import AVFoundation
import Foundation
import ImageIO
import SwiftData
import UIKit
import os

// 잠금 카메라 확장이 넘긴 서명 전 촬영분을 부모 앱의 기존 증거 경로로 봉인한다.
// 확장은 서명 키에 접근하지 않는다. 사진은 사진 증거 패키지(V2)로, 영상은 앱 안 녹화와 같은 사이드카 경로로 간다.
//
// 관측값 원칙: 촬영 시각은 확장이 기록한 값을 그대로 옮기고, 잠금 상태에서 얻지 못한 위치는 비워 둔다.
// 해상도·프레임률·코덱은 파일에서 읽은 값만 적는다.
@MainActor
struct LockedCaptureEvidenceSealer {
    enum SealError: Error {
        case missingCaptureTime
        case unsupportedMediaType
        case malformedPhoto
        case photoPipeline(PhotoEvidenceCapturePipelineErrorV2)
        case existingPackageMismatch
        case missingVideoTrack
    }

    static let photoMediaType = "image/jpeg"
    static let videoMediaType = "video/quicktime"

    let modelContext: ModelContext
    var photoPackageRoot: URL = FileStorage.photoEvidencePackageRoot

    private static let logger = Logger(subsystem: "com.bbdyno.app.provika", category: "LockedCaptureSeal")

    var dependencies: LockedCaptureImportCoordinator.Dependencies {
        .init(
            protectedDataAvailable: { UIApplication.shared.isProtectedDataAvailable },
            verify: { mediaURL, handoff in await Self.verify(mediaURL, handoff) },
            persist: { mediaURL, handoff in try await seal(mediaURL, handoff) },
            quarantine: { directory, reason in try Self.quarantine(directory, reason: reason) }
        )
    }

    // MARK: - 검증

    /// 봉인 전에 미디어가 주장하는 형식 그대로 읽히는지 확인한다. 촬영 시각이 없는 인계분은 받지 않는다.
    static func verify(_ mediaURL: URL, _ handoff: LockedCaptureHandoff) async -> Bool? {
        guard handoff.capturedDate != nil else { return false }
        switch handoff.mediaType {
        case photoMediaType:
            guard let data = try? Data(contentsOf: mediaURL) else { return false }
            return jpegDimensions(of: data) != nil
        case videoMediaType:
            let asset = AVURLAsset(url: mediaURL)
            guard (try? await asset.load(.isPlayable)) == true else { return false }
            return ((try? await asset.loadTracks(withMediaType: .video)) ?? []).isEmpty == false
        default:
            return false
        }
    }

    // MARK: - 봉인

    func seal(_ mediaURL: URL, _ handoff: LockedCaptureHandoff) async throws {
        guard let capturedAt = handoff.capturedDate else { throw SealError.missingCaptureTime }
        switch handoff.mediaType {
        case Self.photoMediaType:
            try await sealPhoto(mediaURL, handoffID: handoff.handoffID, capturedAt: capturedAt)
        case Self.videoMediaType:
            try await sealVideo(mediaURL, startedAt: capturedAt)
        default:
            throw SealError.unsupportedMediaType
        }
    }

    private func sealPhoto(_ mediaURL: URL, handoffID: UUID, capturedAt: Date) async throws {
        // 인계 ID 를 패키지 ID 로 써서, 봉인 직후 앱이 죽어도 다음 실행에서 같은 촬영분을 두 번 만들지 않는다.
        let recordID = PhotoEvidenceVerticalSliceCoordinator.recordID(forPackageID: handoffID)
        var descriptor = FetchDescriptor<EvidenceRecord>(predicate: #Predicate { $0.id == recordID })
        descriptor.fetchLimit = 1
        guard try modelContext.fetchCount(descriptor) == 0 else { return }

        let data = try Data(contentsOf: mediaURL)
        guard let dimensions = Self.jpegDimensions(of: data) else { throw SealError.malformedPhoto }

        // 패키지는 게시됐지만 기록 저장 전에 중단된 경우. 덮어쓰지 않고, 같은 미디어의 유효한 패키지일 때만 이어 간다.
        let packageDirectory = photoPackageRoot.appendingPathComponent(handoffID.uuidString.lowercased(), isDirectory: true)
        if FileManager.default.fileExists(atPath: packageDirectory.path) {
            guard PhotoEvidencePackageVerifierV2().verify(packageDirectory: packageDirectory) == .valid,
                  let claimData = try? Data(contentsOf: packageDirectory.appendingPathComponent("claim.json")),
                  let claim = try? JSONDecoder().decode(PhotoEvidenceClaimV2.self, from: claimData),
                  claim.media.sha256 == HashCalculator.sha256(of: data) else {
                throw SealError.existingPackageMismatch
            }
            try PhotoEvidenceVerticalSliceCoordinator.persistRecord(
                claim: claim, packageDirectory: packageDirectory, modelContext: modelContext
            )
            return
        }

        let pipeline = PhotoEvidenceCapturePipelineV2(rootDirectory: photoPackageRoot, packageIDProvider: { handoffID })
        let capture = PhotoEvidenceCaptureResultV2(
            fileData: data,
            pixelWidth: dimensions.width,
            pixelHeight: dimensions.height,
            mediaType: Self.photoMediaType,
            capturedAt: capturedAt
        )
        let outcome = await withCheckedContinuation { continuation in
            // 잠금 상태에서는 위치를 받지 못했으므로 좌표를 비워 둔다.
            pipeline.capture(capture, location: nil) { continuation.resume(returning: $0) }
        }
        switch outcome {
        case let .success(publishedDirectory, claim):
            try PhotoEvidenceVerticalSliceCoordinator.persistRecord(
                claim: claim, packageDirectory: publishedDirectory, modelContext: modelContext
            )
        case let .failure(error):
            throw SealError.photoPipeline(error)
        }
    }

    private func sealVideo(_ mediaURL: URL, startedAt: Date) async throws {
        let hash = try await Task.detached { try HashCalculator.sha256(of: mediaURL) }.value
        // 같은 해시의 녹화가 이미 있으면 이전 실행에서 봉인이 끝난 것이다.
        var descriptor = FetchDescriptor<Recording>(predicate: #Predicate { $0.fileHash == hash })
        descriptor.fetchLimit = 1
        guard try modelContext.fetchCount(descriptor) == 0 else { return }

        let observation = try await Self.observeVideo(at: mediaURL)

        let videoURL = FileStorage.generateFileURL(for: startedAt, extension: "mov")
        let sidecarURL = videoURL.deletingPathExtension().appendingPathExtension("json")
        let stagingURL = videoURL.deletingLastPathComponent()
            .appendingPathComponent(".import-\(UUID().uuidString).mov")
        let fileManager = FileManager.default
        var published = false
        defer {
            try? fileManager.removeItem(at: stagingURL)
            if !published {
                try? fileManager.removeItem(at: videoURL)
                try? fileManager.removeItem(at: sidecarURL)
            }
        }

        // 세션 콘텐츠의 원본은 봉인이 끝날 때까지 남겨 둔다. 복사본을 숨김 이름으로 만든 뒤 한 번에 옮긴다.
        try await Task.detached { try FileManager.default.copyItem(at: mediaURL, to: stagingURL) }.value
        guard !fileManager.fileExists(atPath: videoURL.path), !fileManager.fileExists(atPath: sidecarURL.path) else {
            throw CocoaError(.fileWriteFileExists)
        }
        try fileManager.moveItem(at: stagingURL, to: videoURL)

        var metadata = RecordingMetadata.create(
            id: videoURL.deletingPathExtension().lastPathComponent,
            device: .init(
                model: UIDevice.current.name,
                systemVersion: "iOS \(UIDevice.current.systemVersion)",
                identifierForVendor: UIDevice.current.identifierForVendor?.uuidString
            ),
            resolution: "\(observation.width)x\(observation.height)",
            frameRate: observation.frameRate,
            codec: observation.codec,
            startedAt: startedAt
        )
        // 서명에 실패하면 서명 없는 증거를 만들지 않고 다음 기회로 미룬다.
        let signatureService = SignatureService()
        metadata.integrity = .init(
            algorithm: "SHA-256",
            hash: hash,
            signatureAlgorithm: "ECDSA-P256-SHA256",
            signature: try signatureService.sign(data: Data(hash.utf8)).base64EncodedString(),
            publicKey: try signatureService.publicKeyPEM()
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(metadata).write(to: sidecarURL, options: .atomic)

        let recording = Recording(
            id: metadata.id,
            createdAt: startedAt,
            duration: observation.duration,
            fileURL: videoURL,
            sidecarURL: sidecarURL,
            fileHash: hash
        )
        modelContext.insert(recording)
        do {
            try modelContext.save()
        } catch {
            modelContext.delete(recording)
            throw error
        }
        published = true
        Self.logger.info("잠금 촬영 영상 봉인 완료: \(metadata.id)")
    }

    // MARK: - 관측

    private struct VideoObservation {
        let width: Int
        let height: Int
        let frameRate: Int
        let codec: String
        let duration: TimeInterval
    }

    private static func observeVideo(at url: URL) async throws -> VideoObservation {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw SealError.missingVideoTrack
        }
        let duration = try await asset.load(.duration)
        let (naturalSize, transform, frameRate, formats) = try await track.load(
            .naturalSize, .preferredTransform, .nominalFrameRate, .formatDescriptions
        )
        let displaySize = naturalSize.applying(transform)
        return VideoObservation(
            width: Int(abs(displaySize.width).rounded()),
            height: Int(abs(displaySize.height).rounded()),
            frameRate: Int(frameRate.rounded()),
            codec: codecName(formats.first?.mediaSubType),
            duration: duration.seconds
        )
    }

    private static func codecName(_ subType: CMFormatDescription.MediaSubType?) -> String {
        switch subType {
        case .hevc?: "hevc"
        case .h264?: "h264"
        case let other?: other.description
        case nil: "unknown"
        }
    }

    private static func jpegDimensions(of data: Data) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) == 1,
              CGImageSourceGetType(source) == "public.jpeg" as CFString,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
              width > 0, height > 0 else { return nil }
        return (width, height)
    }

    // MARK: - 격리

    /// 받을 수 없는 인계분을 지우지 않고 앱 저장소의 격리 폴더로 옮긴다.
    static func quarantine(_ directory: URL, reason: String) throws {
        let fileManager = FileManager.default
        let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LockedCaptureQuarantine", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        var destination = root.appendingPathComponent(directory.lastPathComponent, isDirectory: true)
        if fileManager.fileExists(atPath: destination.path) {
            destination = root.appendingPathComponent("\(directory.lastPathComponent)-\(UUID().uuidString)", isDirectory: true)
        }
        try fileManager.moveItem(at: directory, to: destination)
        logger.warning("잠금 촬영 인계분 격리: \(reason, privacy: .public)")
    }
}
