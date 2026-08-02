import Foundation
import SwiftData

/// 기존 녹화 행을 변경하지 않고 EvidenceRecord를 추가하는 재개 가능한 마이그레이션이다.
struct LegacyRecordingMigration {
    struct Plan: Sendable {
        let items: [Item]
        let skippedSourceIdentifiers: [String]
        let issues: [Issue]
    }

    struct Item: Sendable {
        let sourceIdentifier: String
        let evidenceIdentifier: String
        let createdAt: Date
        let duration: TimeInterval
        let mediaPath: String
        let metadataPath: String
        let fileHash: String
        let startLatitude: Double?
        let startLongitude: Double?
        let endLatitude: Double?
        let endLongitude: Double?
        let userNote: String?
        let isReported: Bool
        let reportedAt: Date?
        let thumbnailData: Data?
    }

    enum Issue: Equatable, Sendable {
        case missingSourceIdentifier
        case malformedSourceIdentifier(String)
        case malformedMediaPath(String)
        case malformedMetadataPath(String)
        case partialSource(String, missingFields: [String])
    }

    struct Execution: Sendable {
        let insertedSourceIdentifiers: [String]
        let skippedSourceIdentifiers: [String]
        let remainingSourceIdentifiers: [String]
        let issues: [Issue]
    }

    /// Builds a plan from the currently persisted legacy rows.  Keeping the
    /// read separate from execution makes an interrupted migration safe to
    /// inspect and resume without mutating any `Recording` objects.
    func plan(in context: ModelContext) throws -> Plan {
        let recordings = try context.fetch(FetchDescriptor<Recording>())
        let evidence = try context.fetch(FetchDescriptor<EvidenceRecord>())
        return plan(recordings: recordings, existingEvidence: evidence)
    }

    func plan(recordings: [Recording], existingEvidence: [EvidenceRecord]) -> Plan {
        let existing = Set(existingEvidence.compactMap(\.legacySourceIdentifier))
        var planned = Set<String>()
        var items: [Item] = []
        var skipped: [String] = []
        var issues: [Issue] = []

        for recording in recordings.sorted(by: { $0.id < $1.id }) {
            // Keep the persisted value unchanged. It is the durable migration
            // key, so normalizing it would make duplicate suppression differ
            // from the identity stored on the legacy row.
            let sourceIdentifier = recording.id
            guard !sourceIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                issues.append(.missingSourceIdentifier)
                continue
            }
            guard !sourceIdentifier.contains("\n") else {
                issues.append(.malformedSourceIdentifier(recording.id))
                continue
            }
            guard !recording.fileURLString.isEmpty else {
                issues.append(.malformedMediaPath(sourceIdentifier))
                continue
            }
            guard !recording.sidecarURLString.isEmpty else {
                issues.append(.malformedMetadataPath(sourceIdentifier))
                continue
            }
            guard !existing.contains(sourceIdentifier) else {
                skipped.append(sourceIdentifier)
                continue
            }
            // A persisted Recording ID is unique, but callers can provide an
            // arbitrary array.  Do not let a duplicate input turn into a
            // duplicate insert attempt.
            guard planned.insert(sourceIdentifier).inserted else {
                skipped.append(sourceIdentifier)
                continue
            }

            var missingFields: [String] = []
            if recording.fileHash.isEmpty { missingFields.append("fileHash") }
            if recording.duration < 0 { missingFields.append("duration") }
            if !missingFields.isEmpty {
                issues.append(.partialSource(sourceIdentifier, missingFields: missingFields))
            }
            items.append(Item(
                sourceIdentifier: sourceIdentifier,
                evidenceIdentifier: "legacy-recording:" + sourceIdentifier,
                createdAt: recording.createdAt,
                duration: recording.duration,
                mediaPath: recording.fileURLString,
                metadataPath: recording.sidecarURLString,
                fileHash: recording.fileHash,
                startLatitude: recording.startLatitude,
                startLongitude: recording.startLongitude,
                endLatitude: recording.endLatitude,
                endLongitude: recording.endLongitude,
                userNote: recording.userNote,
                isReported: recording.isReported,
                reportedAt: recording.reportedAt,
                thumbnailData: recording.thumbnailData
            ))
        }
        return Plan(items: items, skippedSourceIdentifiers: skipped, issues: issues)
    }

    @discardableResult
    func execute(_ plan: Plan, in context: ModelContext, limit: Int? = nil) throws -> Execution {
        let count = min(max(limit ?? plan.items.count, 0), plan.items.count)
        let candidates = Array(plan.items.prefix(count))
        let existing = try context.fetch(FetchDescriptor<EvidenceRecord>())
        var knownSourceIdentifiers = Set(existing.compactMap(\.legacySourceIdentifier))
        var inserted: [String] = []
        var skipped = plan.skippedSourceIdentifiers

        for item in candidates {
            guard knownSourceIdentifiers.insert(item.sourceIdentifier).inserted else {
                skipped.append(item.sourceIdentifier)
                continue
            }
            context.insert(EvidenceRecord(
                id: item.evidenceIdentifier,
                legacySourceIdentifier: item.sourceIdentifier,
                createdAt: item.createdAt,
                updatedAt: item.createdAt,
                capturedAt: item.createdAt,
                evidenceKindRawValue: EvidenceKind.videoRecording.rawValue,
                verificationStateRawValue: EvidenceVerificationState.unverified.rawValue,
                legacyMediaPath: item.mediaPath,
                legacyMetadataPath: item.metadataPath,
                contentHash: item.fileHash.isEmpty ? nil : item.fileHash,
                duration: item.duration >= 0 ? item.duration : nil,
                startLatitude: item.startLatitude,
                startLongitude: item.startLongitude,
                endLatitude: item.endLatitude,
                endLongitude: item.endLongitude,
                userNote: item.userNote,
                isReported: item.isReported,
                reportedAt: item.reportedAt,
                thumbnailData: item.thumbnailData
            ))
            inserted.append(item.sourceIdentifier)
        }
        try context.save()
        return Execution(
            insertedSourceIdentifiers: inserted,
            skippedSourceIdentifiers: skipped,
            remainingSourceIdentifiers: plan.items.dropFirst(count).map(\.sourceIdentifier),
            issues: plan.issues
        )
    }

    /// Plans and executes the next deterministic batch from persistent
    /// storage. Re-running this after an interruption skips rows already
    /// marked with their legacy source identifier.
    @discardableResult
    func execute(in context: ModelContext, limit: Int? = nil) throws -> Execution {
        try execute(try plan(in: context), in: context, limit: limit)
    }
}
