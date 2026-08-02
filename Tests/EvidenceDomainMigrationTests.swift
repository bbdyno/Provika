import SwiftData
import XCTest
@testable import Provika

@MainActor
final class EvidenceDomainMigrationTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Recording.self, EvidenceProject.self, EvidenceRecord.self, configurations: configuration)
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
        super.tearDown()
    }

    func testEvidenceModelsPersistAndQueryOptionalProjectMembership() throws {
        let project = EvidenceProject(id: "project-1", name: "Road report")
        let assigned = EvidenceRecord(id: "record-1", capturedAt: Date(timeIntervalSinceReferenceDate: 1), project: project)
        let unassigned = EvidenceRecord(id: "record-2", capturedAt: Date(timeIntervalSinceReferenceDate: 2))
        context.insert(project)
        context.insert(assigned)
        context.insert(unassigned)
        try context.save()

        let records = try context.fetch(FetchDescriptor<EvidenceRecord>(sortBy: [SortDescriptor(\.id)]))
        XCTAssertEqual(records.map(\.id), ["record-1", "record-2"])
        XCTAssertEqual(records.first?.project?.id, "project-1")
        XCTAssertEqual(records.first?.projectID, "project-1")
        XCTAssertNil(records.last?.project)
        XCTAssertNil(records.last?.projectID)
        XCTAssertEqual(project.records.map(\.id), ["record-1"])
    }

    func testUnknownRawValuesFallBackWithoutChangingStoredValues() {
        let record = EvidenceRecord(
            id: "record-raw",
            capturedAt: .now,
            evidenceKindRawValue: "future_evidence_kind",
            verificationStateRawValue: "future_verification_state"
        )

        XCTAssertEqual(record.evidenceKind, .unknown)
        XCTAssertEqual(record.verificationState, .unknown)
        XCTAssertEqual(record.evidenceKindRawValue, "future_evidence_kind")
        XCTAssertEqual(record.verificationStateRawValue, "future_verification_state")
    }

    func testMigrationPreservesLegacyFieldsAndDoesNotModifySource() throws {
        let createdAt = Date(timeIntervalSinceReferenceDate: 4_200)
        let thumbnail = Data([1, 2, 3])
        let legacy = recording(id: "legacy-a", createdAt: createdAt, duration: 12.5, hash: "abc", note: "note", isReported: true, reportedAt: createdAt.addingTimeInterval(1), thumbnail: thumbnail)
        context.insert(legacy)
        try context.save()

        let migration = LegacyRecordingMigration()
        let plan = try migration.plan(in: context)
        let execution = try migration.execute(plan, in: context)
        let evidence = try XCTUnwrap(context.fetch(FetchDescriptor<EvidenceRecord>()).first)

        XCTAssertEqual(execution.insertedSourceIdentifiers, ["legacy-a"])
        XCTAssertEqual(evidence.id, "legacy-recording:legacy-a")
        XCTAssertEqual(evidence.legacySourceIdentifier, legacy.id)
        XCTAssertEqual(evidence.capturedAt, createdAt)
        XCTAssertEqual(evidence.duration, 12.5)
        XCTAssertEqual(evidence.legacyMediaPath, "/tmp/legacy-a.mov")
        XCTAssertEqual(evidence.legacyMetadataPath, "/tmp/legacy-a.json")
        XCTAssertEqual(evidence.contentHash, "abc")
        XCTAssertEqual(evidence.userNote, "note")
        XCTAssertTrue(evidence.isReported)
        XCTAssertEqual(evidence.reportedAt, createdAt.addingTimeInterval(1))
        XCTAssertEqual(evidence.thumbnailData, thumbnail)
        XCTAssertEqual(evidence.evidenceKindRawValue, "video_recording")
        XCTAssertEqual(evidence.verificationStateRawValue, "unverified")
        XCTAssertEqual(legacy.fileHash, "abc")
        XCTAssertEqual(legacy.userNote, "note")
    }

    func testPlannerReportsMissingMalformedAndPartialSources() {
        let missing = recording(id: " ", createdAt: .now)
        let malformedPath = recording(id: "bad-path", createdAt: .now)
        malformedPath.fileURLString = ""
        let partial = recording(id: "partial", createdAt: .now, duration: -1, hash: "")

        let plan = LegacyRecordingMigration().plan(recordings: [missing, malformedPath, partial], existingEvidence: [])

        XCTAssertEqual(plan.items.map(\.sourceIdentifier), ["partial"])
        XCTAssertTrue(plan.issues.contains(.missingSourceIdentifier))
        XCTAssertTrue(plan.issues.contains(.malformedMediaPath("bad-path")))
        XCTAssertTrue(plan.issues.contains(.partialSource("partial", missingFields: ["fileHash", "duration"])))
    }

    func testMigrationSuppressesDuplicatesAndResumesAfterInterruption() throws {
        let first = recording(id: "legacy-1", createdAt: Date(timeIntervalSinceReferenceDate: 1))
        let second = recording(id: "legacy-2", createdAt: Date(timeIntervalSinceReferenceDate: 2))
        context.insert(first)
        context.insert(second)
        try context.save()

        let migration = LegacyRecordingMigration()
        let firstPlan = migration.plan(recordings: [second, first], existingEvidence: [])
        let interrupted = try migration.execute(firstPlan, in: context, limit: 1)
        XCTAssertEqual(interrupted.insertedSourceIdentifiers, ["legacy-1"])
        XCTAssertEqual(interrupted.remainingSourceIdentifiers, ["legacy-2"])

        let existing = try context.fetch(FetchDescriptor<EvidenceRecord>())
        let resumedPlan = migration.plan(recordings: [first, second], existingEvidence: existing)
        XCTAssertEqual(resumedPlan.skippedSourceIdentifiers, ["legacy-1"])
        let resumed = try migration.execute(resumedPlan, in: context)
        XCTAssertEqual(resumed.insertedSourceIdentifiers, ["legacy-2"])

        let duplicatePlan = migration.plan(recordings: [first, second], existingEvidence: try context.fetch(FetchDescriptor<EvidenceRecord>()))
        let duplicate = try migration.execute(duplicatePlan, in: context)
        XCTAssertTrue(duplicate.insertedSourceIdentifiers.isEmpty)
        XCTAssertEqual(try context.fetch(FetchDescriptor<EvidenceRecord>()).count, 2)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Recording>()).count, 2)
    }

    func testMigrationPreservesTheExactLegacySourceIdentifier() {
        let legacy = recording(id: " legacy source ", createdAt: .now)

        let plan = LegacyRecordingMigration().plan(recordings: [legacy], existingEvidence: [])

        XCTAssertEqual(plan.items.map(\.sourceIdentifier), [" legacy source "])
        XCTAssertEqual(plan.items.map(\.evidenceIdentifier), ["legacy-recording: legacy source "])
        XCTAssertTrue(plan.issues.isEmpty)
    }

    func testPersistentExecutorSuppressesRepeatedInputAndCanResume() throws {
        let legacy = recording(id: "legacy-repeat", createdAt: Date(timeIntervalSinceReferenceDate: 10))
        context.insert(legacy)
        try context.save()

        let migration = LegacyRecordingMigration()
        let inputPlan = migration.plan(recordings: [legacy, legacy], existingEvidence: [])
        XCTAssertEqual(inputPlan.items.map(\.sourceIdentifier), ["legacy-repeat"])
        XCTAssertEqual(inputPlan.skippedSourceIdentifiers, ["legacy-repeat"])

        let execution = try migration.execute(in: context)
        XCTAssertEqual(execution.insertedSourceIdentifiers, ["legacy-repeat"])
        XCTAssertEqual(try context.fetch(FetchDescriptor<Recording>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<EvidenceRecord>()).count, 1)
    }

    private func recording(
        id: String,
        createdAt: Date,
        duration: TimeInterval = 5,
        hash: String = "hash",
        note: String? = nil,
        isReported: Bool = false,
        reportedAt: Date? = nil,
        thumbnail: Data? = nil
    ) -> Recording {
        Recording(
            id: id,
            createdAt: createdAt,
            duration: duration,
            fileURL: URL(fileURLWithPath: "/tmp/\(id).mov"),
            sidecarURL: URL(fileURLWithPath: "/tmp/\(id).json"),
            fileHash: hash,
            startLatitude: 37.5,
            startLongitude: 127.0,
            endLatitude: 37.6,
            endLongitude: 127.1,
            userNote: note,
            isReported: isReported,
            reportedAt: reportedAt,
            thumbnailData: thumbnail
        )
    }
}
