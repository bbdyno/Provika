import XCTest
@testable import Provika

final class EvidenceDataSafetyTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("EvidenceDataSafetyTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testRetentionUsesInjectedClockAtTheBoundary() {
        let now = Date(timeIntervalSinceReferenceDate: 50_000)
        let safety = EvidenceDataSafety(clock: { now })
        let policy = EvidenceDataSafety.RetentionPolicy(maximumAge: 60)

        XCTAssertEqual(safety.retentionDecision(createdAt: now.addingTimeInterval(-59), policy: policy), .retain)
        XCTAssertEqual(safety.retentionDecision(createdAt: now.addingTimeInterval(-60), policy: policy), .delete)
        XCTAssertEqual(safety.retentionDecision(createdAt: now.addingTimeInterval(1), policy: policy), .rejectFutureTimestamp)
    }

    func testManifestRequiresEveryArtifactFamilyExactlyOnceAndKeepsOptionalRowID() throws {
        XCTAssertThrowsError(try EvidenceDataSafety.DeletionManifest(root: root, artifacts: []))
        let duplicate = file("same.bin")
        XCTAssertThrowsError(try EvidenceDataSafety.DeletionManifest(
            root: root,
            artifacts: EvidenceDataSafety.ArtifactFamily.allCases.map { .init(family: $0, url: duplicate) }
        ))
        let manifest = try manifest(locations: [.video: file("movie.mov")], rowID: "local-row-1")
        XCTAssertEqual(manifest.persistenceRowIdentifier, "local-row-1")
        XCTAssertEqual(manifest.artifacts.count, EvidenceDataSafety.ArtifactFamily.allCases.count)
        XCTAssertEqual(manifest.artifacts.first(where: { $0.family == .photo })?.url, nil)
    }

    func testDeletionIsCompleteForAllArtifactFamiliesAndIdempotent() throws {
        var locations: [EvidenceDataSafety.ArtifactFamily: URL] = [:]
        for family in EvidenceDataSafety.ArtifactFamily.allCases {
            let target = file("\(family.rawValue).bin")
            try Data("fixture".utf8).write(to: target)
            locations[family] = target
        }
        let safety = EvidenceDataSafety()
        let manifest = try manifest(locations: locations)

        let first = try safety.delete(manifest)
        XCTAssertTrue(first.isComplete)
        XCTAssertEqual(first.deletedFamilies, Set(EvidenceDataSafety.ArtifactFamily.allCases))
        XCTAssertTrue(locations.values.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) })

        let second = try safety.delete(manifest)
        XCTAssertTrue(second.isComplete)
        XCTAssertEqual(second.alreadyAbsentFamilies, Set(EvidenceDataSafety.ArtifactFamily.allCases))
    }

    func testPartialDeletionFailureIsReportedWithoutHidingOtherSuccesses() throws {
        let video = file("video.mov")
        let metadata = file("metadata.json")
        try Data().write(to: video)
        try Data().write(to: metadata)
        let fs = FailingFileSystem(failingURL: metadata)
        let report = try EvidenceDataSafety(fileSystem: fs).delete(manifest(locations: [.video: video, .metadata: metadata]))

        XCTAssertEqual(report.deletedFamilies, [.video])
        XCTAssertEqual(report.failures[.metadata]?.code, .filesystemFailure)
        XCTAssertFalse(FileManager.default.fileExists(atPath: video.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: metadata.path))
    }

    func testRejectsOutsideRootTraversalAndSymlinkEscapeWithoutTouchingDestination() throws {
        let outside = FileManager.default.temporaryDirectory.appendingPathComponent("EvidenceDataSafetyOutside-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: outside) }
        try Data("safe".utf8).write(to: outside)
        let safety = EvidenceDataSafety()

        XCTAssertUnsafe(try safety.delete(manifest(locations: [.video: outside])), .outsideRoot)
        XCTAssertUnsafe(try safety.delete(manifest(locations: [.video: root.appendingPathComponent("../\(outside.lastPathComponent)")])), .traversal)

        let link = root.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        XCTAssertUnsafe(try safety.delete(manifest(locations: [.video: link])), .symbolicLink)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outside.path))
    }

    func testRejectsDanglingSymlinkInsteadOfTreatingItAsAbsent() throws {
        let link = root.appendingPathComponent("dangling-link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: root.appendingPathComponent("missing-target"))

        XCTAssertUnsafe(try EvidenceDataSafety().delete(manifest(locations: [.video: link])), .symbolicLink)
        XCTAssertTrue((try FileManager.default.attributesOfItem(atPath: link.path)[.type] as? FileAttributeType) == .typeSymbolicLink)
    }

    func testRejectsSymlinkNestedInsideADirectoryArtifact() throws {
        let package = root.appendingPathComponent("package", isDirectory: true)
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        let outside = FileManager.default.temporaryDirectory.appendingPathComponent("EvidenceDataSafetyOutside-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: outside) }
        try Data().write(to: outside)
        try FileManager.default.createSymbolicLink(at: package.appendingPathComponent("escape"), withDestinationURL: outside)

        XCTAssertUnsafe(try EvidenceDataSafety().delete(manifest(locations: [.evidencePackage: package])), .symbolicLink)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outside.path))
    }

    func testRecoveryRequiresOwnedDirectChildAndMarkerThenIsIdempotent() throws {
        let stagingRoot = root.appendingPathComponent("staging", isDirectory: true)
        let owner = "operation-123"
        let staging = stagingRoot.appendingPathComponent(owner, isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        try Data(owner.utf8).write(to: staging.appendingPathComponent(".provika-staging-owner"))
        try Data().write(to: staging.appendingPathComponent("temporary.bin"))
        let safety = EvidenceDataSafety()

        XCTAssertEqual(try safety.recoverInterruptedStaging(stagingDirectory: staging, stagingRoot: stagingRoot, ownerToken: owner), .removed)
        XCTAssertEqual(try safety.recoverInterruptedStaging(stagingDirectory: staging, stagingRoot: stagingRoot, ownerToken: owner), .alreadyAbsent)
    }

    func testRecoveryRejectsWrongOwnerMarkerAndNestedStagingPath() throws {
        let stagingRoot = root.appendingPathComponent("staging", isDirectory: true)
        let staging = stagingRoot.appendingPathComponent("owner", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        try Data("someone-else".utf8).write(to: staging.appendingPathComponent(".provika-staging-owner"))
        let safety = EvidenceDataSafety()

        XCTAssertUnsafe(try safety.recoverInterruptedStaging(stagingDirectory: staging, stagingRoot: stagingRoot, ownerToken: "owner"), .invalidStagingOwnership)
        let nested = staging.appendingPathComponent("nested")
        XCTAssertUnsafe(try safety.recoverInterruptedStaging(stagingDirectory: nested, stagingRoot: stagingRoot, ownerToken: "nested"), .invalidStagingOwnership)
    }

    func testDiagnosticsAreRedacted() throws {
        let secret = root.appendingPathComponent("very-sensitive-location.mov")
        try Data().write(to: secret)
        let report = try EvidenceDataSafety(fileSystem: FailingFileSystem(failingURL: secret)).delete(manifest(locations: [.video: secret]))
        let diagnostic = try XCTUnwrap(report.failures[.video])
        XCTAssertFalse(String(describing: diagnostic).contains("very-sensitive-location"))
        XCTAssertFalse(String(describing: diagnostic).contains(root.path))
    }

    private func manifest(locations: [EvidenceDataSafety.ArtifactFamily: URL], rowID: String? = nil) throws -> EvidenceDataSafety.DeletionManifest {
        try EvidenceDataSafety.DeletionManifest.complete(root: root, locations: locations, persistenceRowIdentifier: rowID)
    }

    private func file(_ name: String) -> URL { root.appendingPathComponent(name) }

    private func XCTAssertUnsafe<T>(_ expression: @autoclosure () throws -> T, _ code: EvidenceDataSafety.Diagnostic.Code, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try expression(), file: file, line: line) { error in
            guard case let EvidenceDataSafety.Error.unsafePath(diagnostic) = error else {
                return XCTFail("unexpected error: \(error)", file: file, line: line)
            }
            XCTAssertEqual(diagnostic.code, code, file: file, line: line)
        }
    }
}

private final class FailingFileSystem: EvidenceDataSafetyFileSystem {
    private let base = FileManager.default
    private let failingURL: URL

    init(failingURL: URL) { self.failingURL = failingURL }
    func itemExists(at url: URL) -> Bool { (try? base.attributesOfItem(atPath: url.path)) != nil }
    func fileExists(at url: URL) -> Bool { base.fileExists(atPath: url.path) }
    func isDirectory(at url: URL) -> Bool { var value: ObjCBool = false; _ = base.fileExists(atPath: url.path, isDirectory: &value); return value.boolValue }
    func isSymbolicLink(at url: URL) throws -> Bool { (try base.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType) == .typeSymbolicLink }
    func contentsOfDirectory(at url: URL) throws -> [URL] { try base.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) }
    func removeItem(at url: URL) throws { if url == failingURL { throw NSError(domain: "synthetic", code: 1) }; try base.removeItem(at: url) }
    func data(at url: URL) throws -> Data { try Data(contentsOf: url) }
}
