import Foundation
import XCTest
@testable import Provika

final class ChinaAppStoreReadinessTests: XCTestCase {
    func testMetadataCandidateCoversRequiredFields() throws {
        let value = try metadata()
        for key in ["schemaVersion", "versionString", "locale", "appName", "subtitle", "description", "keywords", "promotionalText", "releaseNotes", "screenshotCopy", "previewCaptions", "privacyURL", "supportURL", "reviewNotes", "usageDescriptions", "storeKitProducts", "restoreCopy", "productPageStatus", "qualifiedLanguageReview", "claimsPolicyVersion"] {
            XCTAssertNotNil(value[key], key)
        }
        XCTAssertEqual(value["schemaVersion"] as? String, "2.0")
        XCTAssertEqual(value["versionString"] as? String, "2.0")
        XCTAssertEqual(value["locale"] as? String, "zh-Hans")
    }

    func testEveryStoreKitProductHasSimplifiedChineseLocalization() throws {
        let text = try source("Provika.storekit")
        XCTAssertEqual(text.components(separatedBy: "\"locale\" : \"zh_CN\"").count - 1, 3)
    }

    func testEveryStoreKitProductHasFiveLocalizations() throws {
        let data = try Data(contentsOf: repositoryURL("Provika.storekit"))
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let products = try XCTUnwrap(root["products"] as? [[String: Any]])
        let required = Set(["en_US", "ko_KR", "zh_CN", "zh_TW", "ja_JP"])
        XCTAssertEqual(products.count, 3)
        for product in products {
            let localizations = try XCTUnwrap(product["localizations"] as? [[String: Any]])
            XCTAssertEqual(Set(localizations.compactMap { $0["locale"] as? String }), required)
            XCTAssertTrue(localizations.allSatisfy {
                !(($0["displayName"] as? String) ?? "").isEmpty &&
                    !(($0["description"] as? String) ?? "").isEmpty
            })
        }
    }

    func testStoreKitUsesLocalizedDisplayPrice() throws {
        XCTAssertTrue(try source("Sources/Core/Purchase/TipStore.swift").contains("Product"))
        XCTAssertTrue(try source("Sources/Features/Settings/Views/SupportDeveloperView.swift").contains("product.displayPrice"))
    }

    func testProhibitedClaimsScanAllReleaseSurfaces() throws {
        let surfaces = try [
            source("Release/ChinaMainland/AppStoreMetadata.zh-Hans.json"),
            source("Release/ChinaMainland/ChinaReleaseChecklist.md")
        ].joined(separator: "\n").lowercased()
        for claim in ["guaranteed authentic", "court-approved", "government certified", "regulatory approved"] {
            XCTAssertFalse(surfaces.contains(claim))
        }
    }

    func testBinaryAndMetadataReadinessAreSeparate() {
        let result = ChinaAppStoreReadiness.evaluate(.init(evidenceDigest: "d", binary: true, global: false, chinaMainland: nil, ownerEvidence: nil, appStoreConnect: nil, humanReview: nil))
        XCTAssertEqual(result.binary, .ready)
        XCTAssertEqual(result.global, .blocked)
    }

    func testMissingOwnerEvidenceAbstains() {
        let result = ChinaAppStoreReadiness.evaluate(.init(evidenceDigest: "d", binary: true, global: true, chinaMainland: true, ownerEvidence: nil, appStoreConnect: "a", humanReview: "h"))
        XCTAssertEqual(result.chinaMainland, .abstain)
    }

    func testGlobalAndChinaStatusesAreSeparate() {
        let result = ChinaAppStoreReadiness.evaluate(.init(evidenceDigest: "d", binary: true, global: true, chinaMainland: false, ownerEvidence: "o", appStoreConnect: "a", humanReview: "h"))
        XCTAssertEqual(result.global, .ready)
        XCTAssertEqual(result.chinaMainland, .blocked)
    }

    func testNoAutomatedRegulatoryApproval() throws {
        let source = try self.source("Sources/Core/Release/ChinaAppStoreReadiness.swift")
        XCTAssertFalse(source.contains("regulatoryApproved = true"))
        XCTAssertTrue(source.contains("ABSTAIN"))
    }

    private func metadata() throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: repositoryURL("Release/ChinaMainland/AppStoreMetadata.zh-Hans.json"))) as? [String: Any])
    }

    private func repositoryURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(path)
    }

    private func source(_ path: String) throws -> String { try String(contentsOf: repositoryURL(path), encoding: .utf8) }
}
