import Foundation

enum LockedCaptureParentImportPolicy {
    static let pending = "pending"
    static let parentOnly = true
    static let idempotent = true
    static let protectedDataUnavailable = "protectedDataUnavailable"
    static let quarantine = "quarantine"
    static let independentlyVerified = "independentlyVerified"
}

enum LockedStateSigningKeyPolicy {
    /// Locked capture content is unsigned pending input. Only the parent app's
    /// established evidence pipeline may seal it after import and validation.
    static let extensionMaySealEvidence = false
    static let access = "parentOnly"
}

struct LockedCaptureHandoff: Codable, Equatable {
    static let currentSchemaVersion = "1.0"
    let schemaVersion: String
    let handoffID: UUID
    let mediaFileName: String
    let mediaType: String
    let byteCount: Int
    /// 확장이 촬영 순간에 읽은 기기 시계(영상은 녹화 시작 시각). 부모 앱은 이 값을 그대로 옮기며,
    /// 값이 없으면 가져온 시각으로 대신 채우지 않는다.
    let capturedAt: String?

    init(handoffID: UUID, mediaFileName: String, mediaType: String, byteCount: Int, capturedAt: Date? = nil) {
        schemaVersion = Self.currentSchemaVersion
        self.handoffID = handoffID
        self.mediaFileName = mediaFileName
        self.mediaType = mediaType
        self.byteCount = byteCount
        self.capturedAt = capturedAt.map(Self.timestamp(from:))
    }

    var capturedDate: Date? {
        capturedAt.flatMap { Self.makeFormatter().date(from: $0) }
    }

    static func timestamp(from date: Date) -> String {
        makeFormatter().string(from: date)
    }

    private static func makeFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }
}

enum LockedCapturePendingHandoffWriter {
    enum Error: Swift.Error { case empty, tooLarge, invalidExtension }
    static let maximumBytes = 512 * 1_024 * 1_024

    /// Publishes a complete directory with one final rename. Readers therefore
    /// observe either no handoff or the complete media+manifest pair.
    static func publish(
        mediaData: Data,
        fileExtension: String,
        mediaType: String,
        capturedAt: Date? = nil,
        to sessionContentURL: URL,
        fileManager: FileManager = .default
    ) throws -> URL {
        try publish(
            byteCount: mediaData.count,
            fileExtension: fileExtension,
            mediaType: mediaType,
            capturedAt: capturedAt,
            to: sessionContentURL,
            fileManager: fileManager
        ) { try mediaData.write(to: $0, options: [.atomic]) }
    }

    /// 영상처럼 메모리에 올리기 어려운 미디어용. 같은 볼륨 안에서 파일을 옮기므로 복사가 일어나지 않는다.
    static func publish(
        mediaFileAt sourceURL: URL,
        fileExtension: String,
        mediaType: String,
        capturedAt: Date?,
        to sessionContentURL: URL,
        fileManager: FileManager = .default
    ) throws -> URL {
        let byteCount = try sourceURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        return try publish(
            byteCount: byteCount,
            fileExtension: fileExtension,
            mediaType: mediaType,
            capturedAt: capturedAt,
            to: sessionContentURL,
            fileManager: fileManager
        ) { try fileManager.moveItem(at: sourceURL, to: $0) }
    }

    private static func publish(
        byteCount: Int,
        fileExtension: String,
        mediaType: String,
        capturedAt: Date?,
        to sessionContentURL: URL,
        fileManager: FileManager,
        placeMedia: (URL) throws -> Void
    ) throws -> URL {
        guard byteCount > 0 else { throw Error.empty }
        guard byteCount <= maximumBytes else { throw Error.tooLarge }
        guard ["heic", "jpg", "jpeg", "mov"].contains(fileExtension.lowercased()) else { throw Error.invalidExtension }

        let handoffID = UUID()
        let mediaFileName = "original.\(fileExtension.lowercased())"
        let staging = sessionContentURL.appendingPathComponent(".staging-\(handoffID.uuidString)", isDirectory: true)
        let pending = sessionContentURL.appendingPathComponent("pending-\(handoffID.uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: false)
        do {
            try placeMedia(staging.appendingPathComponent(mediaFileName))
            let handoff = LockedCaptureHandoff(
                handoffID: handoffID,
                mediaFileName: mediaFileName,
                mediaType: mediaType,
                byteCount: byteCount,
                capturedAt: capturedAt
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(handoff).write(to: staging.appendingPathComponent("handoff.json"), options: [.atomic])
            try fileManager.moveItem(at: staging, to: pending)
            return pending
        } catch {
            try? fileManager.removeItem(at: staging)
            throw error
        }
    }
}
