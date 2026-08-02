import Foundation
import XCTest
@testable import Provika

final class MultilingualAccessibilityTests: XCTestCase {
    func testKoreanCoverage() throws { try assertLocale("ko") }
    func testEnglishCoverage() throws { try assertLocale("en") }
    func testZhHansCoverage() throws { try assertLocale("zh-Hans") }
    func testZhHantCoverage() throws { try assertLocale("zh-Hant") }
    func testJapaneseCoverage() throws { try assertLocale("ja") }

    func testIconOnlyControls() throws {
        for path in [
            "Sources/Features/Camera/Views/CameraView.swift",
            "Sources/Features/Gallery/Views/VideoThumbnailView.swift",
            "Sources/Features/Settings/Views/SettingsView.swift"
        ] {
            XCTAssertTrue(try source(path).contains("accessibilityLabel"), path)
        }
    }

    func testFocusOrder() {
        XCTAssertEqual(MultilingualAccessibilityPolicy.focusOrder, [.capture, .gallery, .verification, .settings, .purchase, .export])
    }

    func testAccessibilityDynamicType() {
        XCTAssertTrue(MultilingualAccessibilityPolicy.contracts.allSatisfy(\.requiresDynamicType))
    }

    func testContrastAndNonColorCue() {
        XCTAssertTrue(MultilingualAccessibilityPolicy.contracts.allSatisfy(\.requiresNonColorCue))
    }

    func testStatusAnnouncements() {
        for status in MultilingualAccessibilityPolicy.Status.allCases {
            XCTAssertEqual(MultilingualAccessibilityPolicy.accessibilityAnnouncement(for: status, localizedValue: "状态"), "状态")
        }
        XCTAssertEqual(MultilingualAccessibilityPolicy.qualifiedVoiceOverReviewStatus, "AWAITING_EVIDENCE")
    }

    func testCaptureSurface() throws {
        let text = try source("Sources/Features/Camera/Views/CameraView.swift") + source("Sources/Features/Camera/Views/RecordingIndicatorView.swift")
        XCTAssertTrue(text.contains("accessibilityLabel"))
        XCTAssertTrue(text.contains("accessibilityValue"))
    }

    func testGalleryVerificationSurface() throws {
        let text = try source("Sources/Features/Gallery/Views/GalleryView.swift") + source("Sources/Features/Gallery/Views/VideoDetailView.swift")
        XCTAssertTrue(text.contains("accessibilityValue"))
        XCTAssertTrue(text.contains("Signature"))
    }

    func testSettingsPurchaseExportSurface() throws {
        let text = try source("Sources/Features/Settings/Views/SettingsView.swift") + source("Sources/Features/Settings/Views/SupportDeveloperView.swift")
        XCTAssertTrue(text.contains("accessibilityLabel"))
        XCTAssertTrue(text.contains("accessibilityValue"))
        XCTAssertTrue(MultilingualAccessibilityPolicy.Surface.allCases.contains(.export))
    }

    func testClaimsDoNotOverstate() throws {
        let text = try String(contentsOf: repositoryURL("Resources/Localizable.xcstrings"), encoding: .utf8)
        for locale in ChinaClaimsPolicy.Locale.allCases {
            XCTAssertTrue(ChinaClaimsPolicy.findings(in: text, locale: locale).isEmpty)
        }
    }

    func testNoFallback() throws {
        let data = try Data(contentsOf: repositoryURL("Resources/Localizable.xcstrings"))
        let catalog = try JSONDecoder().decode(AccessibilityCatalog.self, from: data)
        XCTAssertTrue(catalog.strings.values.allSatisfy { entry in
            MultilingualAccessibilityPolicy.supportedLocales.allSatisfy {
                !(entry.localizations[$0]?.stringUnit.value.isEmpty ?? true)
            }
        })
    }

    private func assertLocale(_ locale: String) throws {
        let data = try Data(contentsOf: repositoryURL("Resources/Localizable.xcstrings"))
        let catalog = try JSONDecoder().decode(AccessibilityCatalog.self, from: data)
        XCTAssertTrue(catalog.strings.values.allSatisfy { !($0.localizations[locale]?.stringUnit.value.isEmpty ?? true) })
    }

    private func source(_ relativePath: String) throws -> String {
        try String(contentsOf: repositoryURL(relativePath), encoding: .utf8)
    }

    private func repositoryURL(_ relativePath: String) -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(relativePath)
    }
}

private struct AccessibilityCatalog: Decodable {
    struct Entry: Decodable { let localizations: [String: Localization] }
    struct Localization: Decodable { let stringUnit: Unit }
    struct Unit: Decodable { let value: String }
    let strings: [String: Entry]
}
