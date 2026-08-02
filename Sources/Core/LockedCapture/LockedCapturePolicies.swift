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

    init(handoffID: UUID, mediaFileName: String, mediaType: String, byteCount: Int) {
        schemaVersion = Self.currentSchemaVersion
        self.handoffID = handoffID
        self.mediaFileName = mediaFileName
        self.mediaType = mediaType
        self.byteCount = byteCount
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
        to sessionContentURL: URL,
        fileManager: FileManager = .default
    ) throws -> URL {
        guard !mediaData.isEmpty else { throw Error.empty }
        guard mediaData.count <= maximumBytes else { throw Error.tooLarge }
        guard ["heic", "jpg", "jpeg", "mov"].contains(fileExtension.lowercased()) else { throw Error.invalidExtension }

        let handoffID = UUID()
        let mediaFileName = "original.\(fileExtension.lowercased())"
        let staging = sessionContentURL.appendingPathComponent(".staging-\(handoffID.uuidString)", isDirectory: true)
        let pending = sessionContentURL.appendingPathComponent("pending-\(handoffID.uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: false)
        do {
            try mediaData.write(to: staging.appendingPathComponent(mediaFileName), options: [.atomic])
            let handoff = LockedCaptureHandoff(
                handoffID: handoffID,
                mediaFileName: mediaFileName,
                mediaType: mediaType,
                byteCount: mediaData.count
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
