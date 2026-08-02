import Foundation
import SwiftData

enum EvidenceKind: String, CaseIterable, Sendable {
    case videoRecording = "video_recording"
    case unknown = "unknown"
}

enum EvidenceVerificationState: String, CaseIterable, Sendable {
    case unverified = "unverified"
    case verified = "verified"
    case failed = "failed"
    case unknown = "unknown"
}

@Model
final class EvidenceRecord {
    @Attribute(.unique) var id: String
    // This is intentionally not a SwiftData unique attribute: package-backed
    // records have no legacy source and multiple `nil` values must persist.
    // Legacy-row duplicate suppression is enforced by LegacyRecordingMigration
    // using this stable, unchanged source value.
    var legacySourceIdentifier: String?
    var schemaVersion: Int
    var createdAt: Date
    var updatedAt: Date
    var capturedAt: Date
    var evidenceKindRawValue: String
    var verificationStateRawValue: String
    var packagePath: String?
    var legacyMediaPath: String?
    var legacyMetadataPath: String?
    var contentHash: String?
    var duration: TimeInterval?
    var startLatitude: Double?
    var startLongitude: Double?
    var endLatitude: Double?
    var endLongitude: Double?
    var userNote: String?
    var isReported: Bool
    var reportedAt: Date?
    var thumbnailData: Data?
    /// Stable project identifier retained alongside the optional relationship
    /// for deterministic browsing and report queries.
    var projectID: String?
    var project: EvidenceProject?

    var evidenceKind: EvidenceKind {
        EvidenceKind(rawValue: evidenceKindRawValue) ?? .unknown
    }

    var verificationState: EvidenceVerificationState {
        EvidenceVerificationState(rawValue: verificationStateRawValue) ?? .unknown
    }

    init(
        id: String = UUID().uuidString.lowercased(),
        legacySourceIdentifier: String? = nil,
        schemaVersion: Int = 1,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        capturedAt: Date,
        evidenceKindRawValue: String = EvidenceKind.unknown.rawValue,
        verificationStateRawValue: String = EvidenceVerificationState.unverified.rawValue,
        packagePath: String? = nil,
        legacyMediaPath: String? = nil,
        legacyMetadataPath: String? = nil,
        contentHash: String? = nil,
        duration: TimeInterval? = nil,
        startLatitude: Double? = nil,
        startLongitude: Double? = nil,
        endLatitude: Double? = nil,
        endLongitude: Double? = nil,
        userNote: String? = nil,
        isReported: Bool = false,
        reportedAt: Date? = nil,
        thumbnailData: Data? = nil,
        projectID: String? = nil,
        project: EvidenceProject? = nil
    ) {
        self.id = id
        self.legacySourceIdentifier = legacySourceIdentifier
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.capturedAt = capturedAt
        self.evidenceKindRawValue = evidenceKindRawValue
        self.verificationStateRawValue = verificationStateRawValue
        self.packagePath = packagePath
        self.legacyMediaPath = legacyMediaPath
        self.legacyMetadataPath = legacyMetadataPath
        self.contentHash = contentHash
        self.duration = duration
        self.startLatitude = startLatitude
        self.startLongitude = startLongitude
        self.endLatitude = endLatitude
        self.endLongitude = endLongitude
        self.userNote = userNote
        self.isReported = isReported
        self.reportedAt = reportedAt
        self.thumbnailData = thumbnailData
        self.projectID = projectID ?? project?.id
        self.project = project
    }
}
