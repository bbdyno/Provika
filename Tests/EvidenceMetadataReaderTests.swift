import Foundation
import XCTest
@testable import Provika

final class EvidenceMetadataReaderTests: XCTestCase {
    private let fileManager = FileManager.default
    private var temporaryDirectoryURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryDirectoryURL = fileManager.temporaryDirectory
            .appendingPathComponent("EvidenceMetadataReaderTests-\(UUID().uuidString)")
        try fileManager.createDirectory(at: temporaryDirectoryURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectoryURL {
            try? fileManager.removeItem(at: temporaryDirectoryURL)
        }
        try super.tearDownWithError()
    }

    func testLoadsCommittedLegacyVersion1Fixture() {
        let outcome = EvidenceMetadataReader().read(from: fixtureURL())

        guard case let .loaded(metadata) = outcome else {
            return XCTFail("Expected supported metadata, got \(outcome)")
        }
        XCTAssertEqual(metadata.id, "synthetic-legacy-recording-001")
        XCTAssertEqual(metadata.version, "1.0")
        XCTAssertEqual(metadata.recording.duration, 12.25)
    }

    func testReportsMissingFile() {
        let outcome = EvidenceMetadataReader().read(
            from: temporaryDirectoryURL.appendingPathComponent("missing.json")
        )

        XCTAssertMatches(outcome, .missingFile)
    }

    func testReportsDirectoryAsUnreadableFile() {
        let outcome = EvidenceMetadataReader().read(from: temporaryDirectoryURL)

        XCTAssertMatches(outcome, .unreadableFile)
    }

    func testReportsMalformedJSON() throws {
        let url = try write(Data("{not json".utf8), named: "malformed.json")

        XCTAssertMatches(EvidenceMetadataReader().read(from: url), .malformedMetadata)
    }

    func testReportsMissingOrInvalidVersionEnvelopeAsMalformedMetadata() throws {
        let missingVersion = try write(Data("{\"id\": \"missing-version\"}".utf8), named: "missing-version.json")
        let invalidVersion = try write(Data("{\"version\": 1}".utf8), named: "invalid-version.json")

        XCTAssertMatches(EvidenceMetadataReader().read(from: missingVersion), .malformedMetadata)
        XCTAssertMatches(EvidenceMetadataReader().read(from: invalidVersion), .malformedMetadata)
    }

    func testReportsUnsupportedVersionWithoutDecodingFullMetadata() throws {
        let url = try write(Data("{\"version\": \"2.0\"}".utf8), named: "unsupported.json")
        let outcome = EvidenceMetadataReader().read(from: url)

        guard case let .unsupportedVersion(version) = outcome else {
            return XCTFail("Expected unsupported version, got \(outcome)")
        }
        XCTAssertEqual(version, "2.0")
    }

    func testReportsInvalidSupportedVersion1PayloadAsMalformedMetadata() throws {
        let url = try write(Data("{\"version\": \"1.0\"}".utf8), named: "incomplete-v1.json")

        XCTAssertMatches(EvidenceMetadataReader().read(from: url), .malformedMetadata)
    }

    private func write(_ data: Data, named name: String) throws -> URL {
        let url = temporaryDirectoryURL.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }

    private func fixtureURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/legacy-recording-metadata-v1.json")
    }

    private func XCTAssertMatches(
        _ outcome: EvidenceMetadataReader.Outcome,
        _ expected: EvidenceMetadataReader.Outcome,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        switch (outcome, expected) {
        case (.missingFile, .missingFile),
             (.unreadableFile, .unreadableFile),
             (.malformedMetadata, .malformedMetadata):
            break
        default:
            XCTFail("Expected \(expected), got \(outcome)", file: file, line: line)
        }
    }
}
