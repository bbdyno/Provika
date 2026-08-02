import Foundation
import XCTest
@testable import Provika

final class LocalizationFoundationTests: XCTestCase {
    private let requiredAppLocales = Set(["en", "ko", "zh-Hans", "zh-Hant", "ja"])
    private let requiredPermissionDescriptions = [
        "NSCameraUsageDescription": [
            "en": "Provika uses the camera to record traffic violation evidence videos.",
            "ja": "Provikaは、交通違反の証拠映像を録画するためにカメラを使用します。",
            "ko": "Provika는 교통위반 증거 영상 녹화를 위해 카메라를 사용합니다.",
            "zh-Hant": "Provika 使用相機錄製交通違規的證據影片。"
        ],
        "NSMicrophoneUsageDescription": [
            "en": "Provika records audio for evidence integrity.",
            "ja": "Provikaは、証拠の完全性を確保するために音声を録音します。",
            "ko": "Provika는 증거 무결성을 위해 음성을 함께 녹음합니다.",
            "zh-Hant": "Provika 會錄製音訊，以確保證據的完整性。"
        ],
        "NSLocationWhenInUseUsageDescription": [
            "en": "Provika records GPS coordinates for evidence credibility.",
            "ja": "Provikaは、証拠の信頼性を高めるためにGPS座標を記録します。",
            "ko": "Provika는 증거 신뢰성을 위해 GPS 좌표를 기록합니다.",
            "zh-Hant": "Provika 會記錄 GPS 座標，以提高證據的可信度。"
        ],
        "NSPhotoLibraryAddUsageDescription": [
            "en": "Provika can save recorded videos to your photo library.",
            "ja": "Provikaで録画したビデオを写真ライブラリに保存できます。",
            "ko": "Provika가 녹화한 영상을 사진 보관함에 저장할 수 있습니다.",
            "zh-Hant": "Provika 可將錄製的影片儲存到您的照片圖庫。"
        ]
    ]

    func testCatalogsHaveRequiredLocalesAndExactLegacyParity() throws {
        for path in ["Resources/Localizable.xcstrings", "Resources/InfoPlist.xcstrings", "Resources/Widgets/Localizable.xcstrings", "Resources/EvidenceReport.xcstrings"] {
            let catalog = try loadCatalog(path)
            XCTAssertEqual(catalog.sourceLanguage, "en", path)
            for entry in catalog.strings.values {
                XCTAssertEqual(Set(entry.localizations.keys), requiredAppLocales, "\(path) locales")
            }
        }

        XCTAssertGreaterThanOrEqual(try loadCatalog("Resources/Localizable.xcstrings").strings.count, 61)
        XCTAssertEqual(try loadCatalog("Resources/InfoPlist.xcstrings").strings.count, 4)
        XCTAssertEqual(try loadCatalog("Resources/Widgets/Localizable.xcstrings").strings.count, 5)
        XCTAssertEqual(try loadCatalog("Resources/EvidenceReport.xcstrings").strings.count, 5)
    }

    func testPermissionDescriptionsAreFrozen() throws {
        let catalog = try loadCatalog("Resources/InfoPlist.xcstrings")
        for (key, values) in requiredPermissionDescriptions {
            let entry = try XCTUnwrap(catalog.strings[key])
            for (locale, expected) in values {
                XCTAssertEqual(entry.localizations[locale]?.stringUnit.value, expected, "\\(key) [\\(locale)]")
            }
        }
    }

    func testChineseIsExplicitlyProvisionalAndNeverHumanApproved() throws {
        for path in ["Resources/Localizable.xcstrings", "Resources/InfoPlist.xcstrings", "Resources/Widgets/Localizable.xcstrings"] {
            let catalog = try loadCatalog(path)
            for (key, entry) in catalog.strings {
                XCTAssertEqual(entry.comment, "zh-Hans translation is provisional and requires human approval.", "\\(path): \\(key)")
                XCTAssertEqual(entry.localizations["zh-Hans"]?.stringUnit.state, "needs_review", "\\(path): \\(key)")
                XCTAssertFalse(entry.localizations["zh-Hans"]?.stringUnit.value.isEmpty ?? true, "\\(path): \\(key)")
            }
        }
    }

    func testFiveLanguageAppCatalogDoesNotFallback() throws {
        let catalog = try loadCatalog("Resources/Localizable.xcstrings")
        XCTAssertNil(resolve("missing.key", locale: "en", in: catalog))
        XCTAssertEqual(resolve("common.ok", locale: "ja", in: catalog), "OK")
        XCTAssertEqual(resolve("common.ok", locale: "zh-Hant", in: catalog), "好")
        XCTAssertTrue(catalog.strings.values.allSatisfy { !($0.localizations["ja"]?.stringUnit.value.isEmpty ?? true) })
        XCTAssertTrue(catalog.strings.values.allSatisfy { !($0.localizations["zh-Hant"]?.stringUnit.value.isEmpty ?? true) })
        XCTAssertEqual(resolve("settings.publicKey.copy", locale: "ja", in: catalog), "公開鍵をコピー")
        XCTAssertEqual(resolve("settings.publicKey.copy", locale: "zh-Hant", in: catalog), "複製公開金鑰")
    }

    func testGeneratedProvikaStringsSymbolsCompile() {
        XCTAssertFalse(ProvikaStrings.Localizable.Common.ok.isEmpty)
        XCTAssertFalse(ProvikaStrings.Localizable.Camera.PhotoEvidence.Accessibility.label.isEmpty)
        XCTAssertFalse(ProvikaStrings.Localizable.Gallery.Detail.Signature.valid.isEmpty)
        XCTAssertFalse(ProvikaStrings.Localizable.Support.Purchase.Accessibility.pending.isEmpty)
    }

    func testEvidenceCoreRemainsLocaleNeutral() throws {
        let fixture = try Data(contentsOf: repositoryURL("Tests/Fixtures/photo-evidence-claim-v2.json"))
        XCTAssertEqual(HashCalculator.sha256(of: fixture), "0bbaec4b53d80305b589e564e7082bc9fb3fb983c78f499a60d14886f829ebdc")
        let canonicalizer = try source("Sources/Core/Evidence/V2/EvidenceCoreCanonicalizationV2.swift")
        XCTAssertFalse(canonicalizer.contains("ProvikaStrings"))
        XCTAssertFalse(canonicalizer.contains("NSLocalizedString"))
        XCTAssertFalse(canonicalizer.contains("String(localized:"))
    }

    func testRepositoryAwarePresentationStringAuditClassifiesEveryCategory() throws {
        let categories: [AuditCategory: [String]] = [
            .appPresentation: ["Sources/App", "Sources/Features"],
            .widgetPresentation: ["Sources/Widgets", "Sources/Shared/Intents"],
            .accessibility: ["Sources/Features/Camera/Views", "Sources/Features/Settings/Views"],
            .machine: ["Sources/Core/Storage", "Sources/Core/Security", "Sources/Core/Workflow", "Sources/Features/Camera/Services"],
            .evidenceCore: ["Sources/Core/Evidence", "Sources/Core/Export"],
            .diagnostics: ["Sources/Core/Location", "Sources/Core/Purchase", "Sources/Features/Settings/ViewModels"]
        ]
        let root = repositoryURL("")
        let allSwift = try swiftFiles(at: root)
        var covered = Set<AuditCategory>()
        for (category, prefixes) in categories {
            let matching = allSwift.filter { file in prefixes.contains { file.path.contains($0 + "/") } }
            XCTAssertFalse(matching.isEmpty, "\\(category.rawValue) must remain in the audit")
            covered.insert(category)
        }
        XCTAssertEqual(covered, Set(AuditCategory.allCases))

        let appSources = try prefixes("Sources/App", "Sources/Features").map(source)
        XCTAssertTrue(appSources.contains { $0.contains("ProvikaStrings.Localizable") })
        let coreSources = try prefixes("Sources/Core/Evidence", "Sources/Core/Export").map(source)
        XCTAssertTrue(coreSources.allSatisfy { !$0.contains("ProvikaStrings") }, "Signed/Core constants are machine data, not presentation localization.")
    }

    private func resolve(_ key: String, locale: String, in catalog: Catalog) -> String? {
        let entry = catalog.strings[key]
        return entry?.localizations[locale]?.stringUnit.value ?? entry?.localizations[catalog.sourceLanguage]?.stringUnit.value
    }

    private func loadCatalog(_ path: String) throws -> Catalog {
        try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: repositoryURL(path)))
    }

    private func repositoryURL(_ relativePath: String) -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(relativePath)
    }

    private func source(_ path: String) throws -> String {
        let url = path.hasPrefix("/") ? URL(fileURLWithPath: path) : repositoryURL(path)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func prefixes(_ values: String...) throws -> [String] {
        try swiftFiles(at: repositoryURL("")).map(\.path).filter { path in values.contains { path.contains($0 + "/") } }
    }

    private func swiftFiles(at root: URL) throws -> [URL] {
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]))
        return enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }
}

private enum AuditCategory: String, CaseIterable {
    case appPresentation, widgetPresentation, accessibility, machine, evidenceCore, diagnostics
}

private struct Catalog: Decodable {
    let sourceLanguage: String
    let strings: [String: CatalogEntry]
}

private struct CatalogEntry: Decodable {
    let comment: String?
    let localizations: [String: CatalogLocalization]
}

private struct CatalogLocalization: Decodable {
    let stringUnit: CatalogStringUnit
}

private struct CatalogStringUnit: Decodable {
    let state: String
    let value: String
}
