import Foundation
import XCTest
@testable import Provika

final class ZhHansUIProductizationTests: XCTestCase {
    private let catalogs = [
        "Resources/Localizable.xcstrings",
        "Resources/InfoPlist.xcstrings",
        "Resources/Widgets/Localizable.xcstrings"
    ]

    func testNoZhHansFallback() throws {
        for path in catalogs {
            let catalog = try load(path)
            for (key, entry) in catalog.strings {
                let zhHans = try XCTUnwrap(entry.localizations["zh-Hans"]?.stringUnit.value, "\(path): \(key)")
                XCTAssertFalse(zhHans.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    func testPermissionCopy() throws {
        let info = try load("Resources/InfoPlist.xcstrings")
        for key in ["NSCameraUsageDescription", "NSMicrophoneUsageDescription", "NSLocationWhenInUseUsageDescription", "NSPhotoLibraryAddUsageDescription"] {
            XCTAssertNotNil(info.strings[key]?.localizations["zh-Hans"])
        }
    }

    func testCaptureGalleryVerificationSettingsPurchaseExportCoverage() throws {
        let appKeys = Set(try load("Resources/Localizable.xcstrings").strings.keys)
        for prefix in ["camera.", "gallery.", "settings.", "support."] {
            XCTAssertTrue(appKeys.contains { $0.hasPrefix(prefix) })
        }
        XCTAssertTrue(appKeys.contains { $0.contains("signature") }) // verification
        let reportKeys = Set(try load("Resources/EvidenceReport.xcstrings").strings.keys)
        XCTAssertFalse(reportKeys.isEmpty) // export
    }

    func testMarkedTextPreserved() {
        let marked = "证据ａｂＣ"
        let output = CommittedTextTransformPolicy.transform(marked, markedText: true)
        XCTAssertEqual(output.preserveOriginal, marked)
        XCTAssertEqual(output.searchToken, marked)
        XCTAssertTrue(output.composing)
        XCTAssertFalse(output.committed)
    }

    func testCommittedSearchTransform() {
        let committed = "证据ａｂＣ"
        let output = CommittedTextTransformPolicy.transform(committed, markedText: false)
        XCTAssertEqual(output.preserveOriginal, committed)
        XCTAssertEqual(output.searchToken, "证据abc")
        XCTAssertTrue(output.committed)
    }

    func testCompactLayout() throws {
        try assertLayoutDiagnostic(width: 320, dynamicTypeScale: 1.0)
    }

    func testRegularLayout() throws {
        try assertLayoutDiagnostic(width: 768, dynamicTypeScale: 1.0)
    }

    func testDynamicType() throws {
        try assertLayoutDiagnostic(width: 320, dynamicTypeScale: 2.4)
    }

    func testLongLocalizedValues() throws {
        let values = try load("Resources/Localizable.xcstrings").strings.values
            .compactMap { $0.localizations["zh-Hans"]?.stringUnit.value }
        XCTAssertTrue(values.contains { $0.count >= 20 })
        XCTAssertTrue(values.allSatisfy { $0.count < 500 })
    }

    func testClaimsPolicy() throws {
        for path in catalogs + ["Resources/EvidenceReport.xcstrings"] {
            let text = try String(contentsOf: repositoryURL(path), encoding: .utf8)
            for locale in ChinaClaimsPolicy.Locale.allCases {
                XCTAssertTrue(ChinaClaimsPolicy.findings(in: text, locale: locale).isEmpty)
            }
        }
    }

    func testMarketingScreenshotRequiresHumanReview() {
        XCTAssertEqual(ChinaClaimsPolicy.qualifiedReviewStatus, .awaitingEvidence)
    }

    func testEvidenceCoreInvariant() throws {
        let fixture = try Data(contentsOf: repositoryURL("Tests/Fixtures/photo-evidence-claim-v2.json"))
        XCTAssertEqual(HashCalculator.sha256(of: fixture), "0bbaec4b53d80305b589e564e7082bc9fb3fb983c78f499a60d14886f829ebdc")
    }

    private func assertLayoutDiagnostic(width: Double, dynamicTypeScale: Double) throws {
        let values = try load("Resources/Localizable.xcstrings").strings.values
            .compactMap { $0.localizations["zh-Hans"]?.stringUnit.value }
        XCTAssertGreaterThanOrEqual(width, 320)
        XCTAssertGreaterThanOrEqual(dynamicTypeScale, 1)
        XCTAssertTrue(values.allSatisfy { !$0.isEmpty })
        add(XCTAttachment(string: "zh-Hans layout diagnostic width=\(width), dynamicTypeScale=\(dynamicTypeScale), strings=\(values.count)"))
    }

    private func load(_ relativePath: String) throws -> ZhCatalog {
        try JSONDecoder().decode(ZhCatalog.self, from: Data(contentsOf: repositoryURL(relativePath)))
    }

    private func repositoryURL(_ relativePath: String) -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(relativePath)
    }
}

private struct ZhCatalog: Decodable {
    struct Entry: Decodable { let localizations: [String: Localization] }
    struct Localization: Decodable { let stringUnit: StringUnit }
    struct StringUnit: Decodable { let value: String }
    let strings: [String: Entry]
}
