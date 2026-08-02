import Foundation
import CoreGraphics
import XCTest
@testable import Provika

final class PhotoEvidenceExportWorkflowTests: XCTestCase {
    func testPDFExportsOutsideEvidenceSubtreeAndCompletes() throws {
        let fixture = try fixture(); defer { try? FileManager.default.removeItem(at: fixture.root) }
        let workflow = PhotoEvidenceExportWorkflow(verifier: StubVerifier(.valid))
        let result = workflow.export(packageDirectory: fixture.package, destination: fixture.root.appendingPathComponent("export.zip"), operationID: "export")
        guard case let .success(url) = result else { return XCTFail("expected success") }
        let zip = try Data(contentsOf: url)
        XCTAssertTrue(zip.range(of: Data("Photo Evidence Report.pdf".utf8)) != nil)
        XCTAssertTrue(zip.range(of: Data("EvidencePackage/claim.json".utf8)) != nil)
        let pdf = try extractPDF(zip)
        XCTAssertNotNil(CGPDFDocument(CGDataProvider(data: pdf as CFData)!))
        XCTAssertEqual(workflow.stateMachine.state, .completed)
    }
    func testTamperedPackageIsRefusedAndDestinationPreserved() throws {
        let fixture = try fixture(); defer { try? FileManager.default.removeItem(at: fixture.root) }
        let destination = fixture.root.appendingPathComponent("keep.zip"); try Data("keep".utf8).write(to: destination)
        let workflow = PhotoEvidenceExportWorkflow(verifier: StubVerifier(.originalMediaDigestMismatch))
        XCTAssertEqual(workflow.export(packageDirectory: fixture.package, destination: destination, operationID: "x"), .rejected(.originalMediaDigestMismatch))
        XCTAssertEqual(try Data(contentsOf: destination), Data("keep".utf8)); XCTAssertEqual(workflow.stateMachine.state, .failed(failures: 1))
    }
    func testAtomicCleanupCancellationCleansStagingAndState() throws {
        let fixture = try fixture(); defer { try? FileManager.default.removeItem(at: fixture.root) }
        let workflow = PhotoEvidenceExportWorkflow(verifier: StubVerifier(.valid))
        XCTAssertEqual(workflow.export(packageDirectory: fixture.package, destination: fixture.root.appendingPathComponent("x.zip"), operationID: "x", isCancelled: { true }), .cancelled)
        XCTAssertEqual(workflow.stateMachine.state, .cancelled(failures: 0)); XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: fixture.root.path).filter { $0.contains(".x.zip.staging-") }, [])
    }
    func testAtomicCleanupPreservesExistingDestination() throws {
        let fixture = try fixture(); defer { try? FileManager.default.removeItem(at: fixture.root) }
        let destination = fixture.root.appendingPathComponent("existing.zip")
        try Data("existing archive".utf8).write(to: destination)
        let workflow = PhotoEvidenceExportWorkflow(verifier: StubVerifier(.valid))
        XCTAssertEqual(workflow.export(packageDirectory: fixture.package, destination: destination, operationID: "x"), .failed)
        XCTAssertEqual(try Data(contentsOf: destination), Data("existing archive".utf8))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: fixture.root.path).filter { $0.contains(".existing.zip.staging-") }, [])
    }
    func testStoredZIPRejectsUnsafeNamesCollisionsAndLimits() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("source"); try Data([1, 2, 3]).write(to: source)
        let exporter = SafeEvidenceZIPExporter(maximumEntries: 1, maximumEntrySize: 2, maximumTotalSize: 2)
        XCTAssertThrowsError(try exporter.write(entries: [.init(name: "../bad", sourceURL: source)], to: root.appendingPathComponent("a.zip")))
        XCTAssertThrowsError(try exporter.write(entries: [.init(name: "/bad", sourceURL: source)], to: root.appendingPathComponent("a.zip")))
        XCTAssertThrowsError(try exporter.write(entries: [.init(name: "\\bad", sourceURL: source)], to: root.appendingPathComponent("a.zip")))
        XCTAssertThrowsError(try exporter.write(entries: [.init(name: "a\\b", sourceURL: source)], to: root.appendingPathComponent("a.zip")))
        XCTAssertThrowsError(try exporter.write(entries: [.init(name: "a//b", sourceURL: source)], to: root.appendingPathComponent("a.zip")))
        XCTAssertThrowsError(try exporter.write(entries: [.init(name: "C:ambiguous", sourceURL: source)], to: root.appendingPathComponent("a.zip")))
        let names = SafeEvidenceZIPExporter()
        XCTAssertThrowsError(try names.write(entries: [.init(name: "a", sourceURL: source), .init(name: "a", sourceURL: source)], to: root.appendingPathComponent("a.zip")))
        XCTAssertThrowsError(try names.write(entries: [.init(name: "a", sourceURL: source), .init(name: "A", sourceURL: source)], to: root.appendingPathComponent("a.zip")))
        let link = root.appendingPathComponent("link"); try FileManager.default.createSymbolicLink(at: link, withDestinationURL: source)
        XCTAssertThrowsError(try names.write(entries: [.init(name: "link", sourceURL: link)], to: root.appendingPathComponent("a.zip")))
        XCTAssertThrowsError(try exporter.write(entries: [.init(name: "a", sourceURL: source)], to: root.appendingPathComponent("a.zip")))
        XCTAssertThrowsError(try SafeEvidenceZIPExporter(maximumEntries: 1).write(entries: [.init(name: "a", sourceURL: source), .init(name: "b", sourceURL: source)], to: root.appendingPathComponent("count.zip")))
    }
    func testPathTraversalIsRejected() throws {
        let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source"); try Data([1]).write(to: source)
        XCTAssertThrowsError(try SafeEvidenceZIPExporter().write(entries: [.init(name: "../outside", sourceURL: source)], to: root.appendingPathComponent("out.zip")))
    }
    func testDuplicateEntriesAreRejected() throws {
        let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source"); try Data([1]).write(to: source)
        XCTAssertThrowsError(try SafeEvidenceZIPExporter().write(entries: [.init(name: "same", sourceURL: source), .init(name: "same", sourceURL: source)], to: root.appendingPathComponent("out.zip")))
    }
    func testSymlinkSourcesAreRejected() throws {
        let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source"), link = root.appendingPathComponent("link")
        try Data([1]).write(to: source); try FileManager.default.createSymbolicLink(at: link, withDestinationURL: source)
        XCTAssertThrowsError(try SafeEvidenceZIPExporter().write(entries: [.init(name: "link", sourceURL: link)], to: root.appendingPathComponent("out.zip")))
    }
    func testSizeLimitIsRejected() throws {
        let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source"); try Data([1, 2]).write(to: source)
        XCTAssertThrowsError(try SafeEvidenceZIPExporter(maximumEntrySize: 1).write(entries: [.init(name: "large", sourceURL: source)], to: root.appendingPathComponent("out.zip")))
    }
    func testWorkflowStateCompletesAfterVerifiedExport() throws {
        let fixture = try fixture(); defer { try? FileManager.default.removeItem(at: fixture.root) }
        let workflow = PhotoEvidenceExportWorkflow(verifier: StubVerifier(.valid))
        guard case .success = workflow.export(packageDirectory: fixture.package, destination: fixture.root.appendingPathComponent("state.zip"), operationID: "state") else { return XCTFail("expected success") }
        XCTAssertEqual(workflow.stateMachine.state, .completed)
    }
    func testZIPHasValidLocalHeadersCRCAndContents() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("source"); let payload = Data([1, 2, 3]); try payload.write(to: source)
        let output = root.appendingPathComponent("out.zip"); try SafeEvidenceZIPExporter().write(entries: [.init(name: "evidence/a", sourceURL: source)], to: output)
        let archive = try Data(contentsOf: output)
        XCTAssertEqual(read32(archive, 0), 0x04034b50); XCTAssertEqual(read16(archive, 8), 0); XCTAssertEqual(read16(archive, 6), 0x0800)
        let n = read16(archive, 26), body = 30 + n; XCTAssertEqual(Data(archive[body..<(body + payload.count)]), payload)
        XCTAssertEqual(read32(archive, 14), crc32(payload))
        let eocd = try XCTUnwrap(archive.range(of: Data([0x50, 0x4b, 0x05, 0x06]), options: .backwards))
        let eocdOffset = eocd.lowerBound
        XCTAssertEqual(read16(archive, eocdOffset + 8), 1)
        let centralOffset = Int(read32(archive, eocdOffset + 16))
        XCTAssertEqual(read32(archive, centralOffset), 0x02014b50)
        XCTAssertEqual(read16(archive, centralOffset + 10), 0)
        XCTAssertEqual(read32(archive, centralOffset + 16), crc32(payload))
        XCTAssertEqual(read32(archive, centralOffset + 42), 0)
    }
    private func fixture() throws -> (root: URL, package: URL) { let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString), package = root.appendingPathComponent("package"); try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true); let claim = PhotoEvidenceClaimV2(packageID: UUID(), media: .init(fileName: "original.jpg", mediaType: "image/jpeg", pixelWidth: 1, pixelHeight: 1, sha256: "x"), capture: .init(deviceTime: "2026-01-01T00:00:00Z"), app: .init(name: "Provika", version: "1", build: "1"), device: .init(model: "test", systemVersion: "1")); try JSONEncoder().encode(claim).write(to: package.appendingPathComponent("claim.json")); try Data([1,2]).write(to: package.appendingPathComponent("original.jpg")); try Data("{}".utf8).write(to: package.appendingPathComponent("signature.json")); return (root, package) }
    private func temporaryDirectory() throws -> URL { let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true); return root }
    private func extractPDF(_ data: Data) throws -> Data {
        func u16(_ at: Int) -> Int { Int(data[at]) | Int(data[at + 1]) << 8 }
        func u32(_ at: Int) -> Int { Int(data[at]) | Int(data[at + 1]) << 8 | Int(data[at + 2]) << 16 | Int(data[at + 3]) << 24 }
        var offset = 0
        while offset + 30 <= data.count, u32(offset) == 0x04034b50 {
            let size = u32(offset + 18), nameLength = u16(offset + 26), extraLength = u16(offset + 28), start = offset + 30
            let name = try XCTUnwrap(String(data: data[start..<(start + nameLength)], encoding: .utf8))
            let body = start + nameLength + extraLength
            if name == "Photo Evidence Report.pdf" { return Data(data[body..<(body + size)]) }
            offset = body + size
        }
        throw NSError(domain: "PhotoEvidenceExportWorkflowTests", code: 1)
    }
    private func read16(_ data: Data, _ offset: Int) -> Int { Int(data[offset]) | Int(data[offset + 1]) << 8 }
    private func read32(_ data: Data, _ offset: Int) -> UInt32 { UInt32(data[offset]) | UInt32(data[offset + 1]) << 8 | UInt32(data[offset + 2]) << 16 | UInt32(data[offset + 3]) << 24 }
    private func crc32(_ data: Data) -> UInt32 { var crc: UInt32 = 0xffff_ffff; for byte in data { crc ^= UInt32(byte); for _ in 0..<8 { crc = (crc & 1) == 0 ? crc >> 1 : (crc >> 1) ^ 0xedb8_8320 } }; return crc ^ 0xffff_ffff }
}
private struct StubVerifier: PhotoEvidencePackageVerifyingV2 { let value: PhotoEvidencePackageVerificationResultV2; init(_ value: PhotoEvidencePackageVerificationResultV2) { self.value = value }; func verify(packageDirectory: URL) -> PhotoEvidencePackageVerificationResultV2 { value } }
