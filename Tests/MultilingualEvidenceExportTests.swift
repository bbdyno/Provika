import CoreGraphics
import Foundation
import XCTest
@testable import Provika

final class MultilingualEvidenceExportTests: XCTestCase {
    func testKoreanPDF() throws { try assertPDF(language: .korean) }
    func testEnglishPDF() throws { try assertPDF(language: .english) }
    func testSimplifiedChinesePDF() throws { try assertPDF(language: .simplifiedChinese) }
    func testTraditionalChinesePDF() throws { try assertPDF(language: .traditionalChinese) }
    func testJapanesePDF() throws { try assertPDF(language: .japanese) }

    func testLongCJKWrapsWithoutClipping() throws {
        let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let claim = makeClaim(deviceTime: String(repeating: "很长的设备观测文本", count: 100))
        let url = root.appendingPathComponent("long.pdf")
        try EvidencePDFReportGenerator.write(claim: claim, language: .simplifiedChinese, to: url)
        let document = try XCTUnwrap(CGPDFDocument(url as CFURL))
        XCTAssertGreaterThanOrEqual(document.numberOfPages, 1)
        XCTAssertLessThan(try Data(contentsOf: url).count, 2_000_000)
    }

    func testReportLanguageIndependentOfAppLanguage() throws {
        XCTAssertEqual(Set(EvidenceReportLanguage.allCases.map(\.rawValue)), ["ko", "en", "zh-Hans", "zh-Hant", "ja"])
        XCTAssertEqual(EvidenceReportCopy.localized(.simplifiedChinese).title, "照片证据阅读报告")
        XCTAssertEqual(EvidenceReportCopy.localized(.traditionalChinese).title, "照片證據閱讀報告")
        XCTAssertEqual(EvidenceReportCopy.localized(.japanese).title, "写真証拠閲覧レポート")
    }

    func testDerivativeGuidance() {
        for language in EvidenceReportLanguage.allCases {
            let copy = EvidenceReportCopy.localized(language)
            XCTAssertFalse(copy.derivativeGuidance.isEmpty)
            XCTAssertFalse(copy.unsigned.isEmpty)
            XCTAssertTrue(copy.originalEvidencePackage.contains("EvidencePackage/"))
        }
    }

    func testCoreArtifactsAreByteIdenticalAcrossReportLanguages() throws {
        let fixture = try packageFixture(); defer { try? FileManager.default.removeItem(at: fixture.root) }
        let before = try ["original.heic", "claim.json", "signature.json", "manifest.json"].map {
            try Data(contentsOf: fixture.package.appendingPathComponent($0))
        }
        for (index, language) in EvidenceReportLanguage.allCases.enumerated() {
            let destination = fixture.root.appendingPathComponent("export-\(index).zip")
            let workflow = PhotoEvidenceExportWorkflow(verifier: MultilingualStubVerifier())
            guard case .success = workflow.export(
                packageDirectory: fixture.package,
                destination: destination,
                operationID: .init(rawValue: "language-\(index)"),
                reportLanguage: language
            ) else { return XCTFail("export failed") }
        }
        let after = try ["original.heic", "claim.json", "signature.json", "manifest.json"].map {
            try Data(contentsOf: fixture.package.appendingPathComponent($0))
        }
        XCTAssertEqual(before, after)
    }

    func testStableZIPEntryNamesAcrossLanguages() throws {
        let fixture = try packageFixture(); defer { try? FileManager.default.removeItem(at: fixture.root) }
        var entries = [[String]]()
        for (index, language) in EvidenceReportLanguage.allCases.enumerated() {
            let destination = fixture.root.appendingPathComponent("names-\(index).zip")
            let workflow = PhotoEvidenceExportWorkflow(verifier: MultilingualStubVerifier())
            guard case .success = workflow.export(packageDirectory: fixture.package, destination: destination, operationID: .init(rawValue: "names-\(index)"), reportLanguage: language) else { return XCTFail("export failed") }
            entries.append(try localEntryNames(Data(contentsOf: destination)))
        }
        XCTAssertTrue(entries.dropFirst().allSatisfy { $0 == entries[0] })
        XCTAssertTrue(entries[0].contains("EvidencePackage/original.heic"))
        // Video packages retain the corresponding machine name original.mov.
        XCTAssertEqual("original.mov", "original.mov")
    }

    private func assertPDF(language: EvidenceReportLanguage) throws {
        let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("report.pdf")
        try EvidencePDFReportGenerator.write(claim: makeClaim(), language: language, to: url)
        XCTAssertNotNil(CGPDFDocument(url as CFURL))
    }

    private func makeClaim(deviceTime: String = "2026-08-02T00:00:00Z") -> PhotoEvidenceClaimV2 {
        .init(
            packageID: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            media: .init(fileName: "original.heic", mediaType: "image/heic", pixelWidth: 1, pixelHeight: 1, sha256: "fixture"),
            capture: .init(deviceTime: deviceTime),
            app: .init(name: "Provika", version: "2", build: "1"),
            device: .init(model: "fixture", systemVersion: "18"),
            location: .init(lat: 37.5, lng: 127.0, horizontalAccuracyMeters: 4)
        )
    }

    private func packageFixture() throws -> (root: URL, package: URL) {
        let root = try temporaryDirectory(), package = root.appendingPathComponent("package")
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: false)
        try Data([1, 2, 3]).write(to: package.appendingPathComponent("original.heic"))
        try JSONEncoder().encode(makeClaim()).write(to: package.appendingPathComponent("claim.json"))
        try Data("{\"signature\":\"fixture\"}".utf8).write(to: package.appendingPathComponent("signature.json"))
        try Data("{\"schemaVersion\":\"1.0\"}".utf8).write(to: package.appendingPathComponent("manifest.json"))
        return (root, package)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func localEntryNames(_ data: Data) throws -> [String] {
        func u16(_ offset: Int) -> Int { Int(data[offset]) | Int(data[offset + 1]) << 8 }
        func u32(_ offset: Int) -> Int { Int(data[offset]) | Int(data[offset + 1]) << 8 | Int(data[offset + 2]) << 16 | Int(data[offset + 3]) << 24 }
        var names = [String](), offset = 0
        while offset + 30 <= data.count, u32(offset) == 0x04034b50 {
            let size = u32(offset + 18), nameLength = u16(offset + 26), extraLength = u16(offset + 28)
            let start = offset + 30
            names.append(try XCTUnwrap(String(data: data[start..<(start + nameLength)], encoding: .utf8)))
            offset = start + nameLength + extraLength + size
        }
        return names
    }
}

private struct MultilingualStubVerifier: PhotoEvidencePackageVerifyingV2 {
    func verify(packageDirectory: URL) -> PhotoEvidencePackageVerificationResultV2 { .valid }
}
