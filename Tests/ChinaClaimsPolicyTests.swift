import Foundation
import XCTest
@testable import Provika

final class ChinaClaimsPolicyTests: XCTestCase {
    // Explicit negative fixtures. These markers also bind the contract scanners.
    private let PROHIBITED_CLAIMS_KO = ["절대적 진실", "법원 인정", "진짜 위치"]
    private let PROHIBITED_CLAIMS_EN = ["absolute truth", "court accepted", "true location"]
    private let PROHIBITED_CLAIMS_ZH_HANS = ["绝对真实", "法院认可", "真实位置"]

    func testMaintainedMatrixContainsEightBoundedMeanings() throws {
        let data = try Data(contentsOf: repositoryURL("Resources/ClaimsPolicy/ChinaClaimsMatrix.json"))
        let matrix = try JSONDecoder().decode(Matrix.self, from: data)

        XCTAssertEqual(matrix.schemaVersion, "1.0")
        XCTAssertEqual(matrix.reviewStatus, "AWAITING_EVIDENCE")
        XCTAssertEqual(matrix.claims.count, 8)
        XCTAssertGreaterThanOrEqual(matrix.limitations.count, 5)
        for claim in matrix.claims {
            XCTAssertEqual(Set(claim.copy.keys), Set(["ko", "en", "zh-Hans"]))
            XCTAssertTrue(claim.copy.values.allSatisfy { !$0.isEmpty })
        }
    }

    func testNegativeFixturesAreRejectedForEveryMaintainedLocale() {
        for phrase in PROHIBITED_CLAIMS_KO {
            XCTAssertFalse(ChinaClaimsPolicy.permits("광고: \(phrase)", locale: .ko))
        }
        for phrase in PROHIBITED_CLAIMS_EN {
            XCTAssertFalse(ChinaClaimsPolicy.permits("Marketing: \(phrase)", locale: .en))
        }
        for phrase in PROHIBITED_CLAIMS_ZH_HANS {
            XCTAssertFalse(ChinaClaimsPolicy.permits("营销：\(phrase)", locale: .zhHans))
        }
        XCTAssertEqual(ChinaClaimsPolicy.qualifiedReviewStatus, .awaitingEvidence)
    }

    func testPresentRepositorySurfacesContainNoProhibitedCopy() throws {
        // Coverage categories: app, report/export, StoreKit, screenshot metadata, support, privacy.
        let surfacePaths = [
            "Sources/App", "Sources/Features", "Sources/Core/Export",
            "Resources/Localizable.xcstrings", "Resources/EvidenceReport.xcstrings",
            "Resources/InfoPlist.xcstrings", "Resources/PrivacyInfo.xcprivacy",
            "Project.swift"
        ]
        let texts = try surfacePaths.flatMap(scanTexts)
        XCTAssertFalse(texts.isEmpty)
        for text in texts {
            for locale in ChinaClaimsPolicy.Locale.allCases {
                XCTAssertTrue(ChinaClaimsPolicy.findings(in: text, locale: locale).isEmpty)
            }
        }
    }

    private func scanTexts(_ relativePath: String) throws -> [String] {
        let url = repositoryURL(relativePath)
        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return [] }
        if !isDirectory.boolValue {
            return [try String(contentsOf: url, encoding: .utf8)]
        }
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil))
        return try enumerator.compactMap { $0 as? URL }
            .filter { ["swift", "json", "xcstrings", "xcprivacy", "md"].contains($0.pathExtension) }
            .map { try String(contentsOf: $0, encoding: .utf8) }
    }

    private func repositoryURL(_ relativePath: String) -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(relativePath)
    }
}

private struct Matrix: Decodable {
    struct Claim: Decodable { let copy: [String: String] }
    let schemaVersion: String
    let reviewStatus: String
    let claims: [Claim]
    let limitations: [String]
}
