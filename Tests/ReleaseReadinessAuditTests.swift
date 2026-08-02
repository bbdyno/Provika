import Foundation
import XCTest
@testable import Provika

@MainActor
final class ReleaseReadinessAuditTests: XCTestCase {
    func testPrivacyManifest() throws {
        let data = try Data(contentsOf: repositoryURL("Resources/PrivacyInfo.xcprivacy"))
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        XCTAssertEqual(plist["NSPrivacyTracking"] as? Bool, false)
        XCTAssertEqual((plist["NSPrivacyTrackingDomains"] as? NSArray)?.count, 0)
        XCTAssertEqual((plist["NSPrivacyCollectedDataTypes"] as? NSArray)?.count, 0)
        let accessed = try XCTUnwrap(plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        XCTAssertEqual(accessed.count, 1)
        XCTAssertEqual(accessed[0]["NSPrivacyAccessedAPIType"] as? String, "NSPrivacyAccessedAPICategoryUserDefaults")
        XCTAssertEqual(accessed[0]["NSPrivacyAccessedAPITypeReasons"] as? [String], ["CA92.1"])
        XCTAssertTrue(try source("Sources/Features/Settings/ViewModels/SettingsViewModel.swift").contains("UserDefaults.standard"))
    }

    func testUsageDescriptions() throws {
        let project = try source("Project.swift")
        for key in ["NSCameraUsageDescription", "NSMicrophoneUsageDescription", "NSLocationWhenInUseUsageDescription", "NSPhotoLibraryAddUsageDescription"] {
            XCTAssertTrue(project.contains(key))
        }
        XCTAssertFalse(project.contains("entitlements:"))
        XCTAssertEqual(try files(withExtension: "entitlements"), [])
        for key in ["NSCameraUsageDescription", "NSMicrophoneUsageDescription", "NSLocationWhenInUseUsageDescription", "NSPhotoLibraryAddUsageDescription"] {
            XCTAssertEqual(
                try catalogLocales(path: "Resources/InfoPlist.xcstrings", key: key),
                ["en", "ja", "ko", "zh-Hans", "zh-Hant"]
            )
        }
    }

    func testStoreKitConfiguration() throws {
        let data = try Data(contentsOf: repositoryURL("Provika.storekit"))
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let products = try XCTUnwrap(root["products"] as? [[String: Any]])
        XCTAssertEqual(
            Set(products.compactMap { $0["productID"] as? String }),
            ["com.provika.tip.item.small", "com.provika.tip.item.medium", "com.provika.tip.item.large"]
        )
        XCTAssertEqual(products.count, 3)
        for product in products {
            XCTAssertEqual(product["type"] as? String, "Consumable")
            let locales = Set((product["localizations"] as? [[String: Any]] ?? []).compactMap { $0["locale"] as? String })
            XCTAssertEqual(locales, ["en_US", "ko_KR", "zh_CN", "zh_TW", "ja_JP"])
        }
    }

    func testAppStoreConnect20MetadataDraftsCoverFiveLocalesTruthfully() throws {
        let expected: [String: String] = [
            "en-US.json": "en-US",
            "ko-KR.json": "ko-KR",
            "zh-Hans.json": "zh-Hans",
            "zh-Hant.json": "zh-Hant",
            "ja.json": "ja"
        ]
        let requiredKeys = [
            "schemaVersion", "versionString", "locale", "appName", "subtitle",
            "description", "keywords", "promotionalText", "releaseNotes",
            "supportURL", "privacyURL", "reviewNotes", "featureScope",
            "productPageStatus", "qualifiedLanguageReview", "claimsPolicyVersion"
        ]
        for (fileName, locale) in expected {
            let data = try Data(contentsOf: repositoryURL("Release/AppStoreConnect/2.0/\(fileName)"))
            let value = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
            for key in requiredKeys { XCTAssertNotNil(value[key], "\(fileName): \(key)") }
            XCTAssertEqual(value["schemaVersion"] as? String, "2.0")
            XCTAssertEqual(value["versionString"] as? String, "2.0")
            XCTAssertEqual(value["locale"] as? String, locale)
            XCTAssertEqual(value["productPageStatus"] as? String, "repository_draft")
            XCTAssertEqual(value["qualifiedLanguageReview"] as? String, "required")
            XCTAssertTrue((value["supportURL"] as? String)?.hasPrefix("https://") == true)
            XCTAssertTrue((value["privacyURL"] as? String)?.hasPrefix("https://") == true)
            XCTAssertLessThanOrEqual((value["appName"] as? String)?.count ?? Int.max, 30)
            XCTAssertLessThanOrEqual((value["subtitle"] as? String)?.count ?? Int.max, 30)
            XCTAssertLessThanOrEqual(((value["keywords"] as? [String]) ?? []).joined(separator: ",").count, 100)
            XCTAssertLessThanOrEqual((value["promotionalText"] as? String)?.count ?? Int.max, 170)
            XCTAssertLessThanOrEqual((value["description"] as? String)?.count ?? Int.max, 4_000)
            XCTAssertLessThanOrEqual((value["releaseNotes"] as? String)?.count ?? Int.max, 4_000)

            let scope = try XCTUnwrap(value["featureScope"] as? [String: String])
            for implemented in ["photoEvidencePackage", "videoEvidencePackage", "multilingualReadingReport", "offlineVerification"] {
                XCTAssertEqual(scope[implemented], "implemented")
            }
            for deviceValidated in ["activeAppCameraControl", "lockedCaptureExtension"] {
                XCTAssertEqual(scope[deviceValidated], "implementation_candidate_requires_device_validation")
            }
        }
    }

    func testAppStoreConnect20MetadataAvoidsProhibitedClaims() throws {
        let directory = repositoryURL("Release/AppStoreConnect/2.0")
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        XCTAssertEqual(files.filter { $0.pathExtension == "json" }.count, 5)
        let combined = try files.filter { $0.pathExtension == "json" }.map {
            try String(contentsOf: $0, encoding: .utf8).lowercased()
        }.joined(separator: "\n")
        for prohibited in [
            "guaranteed authentic", "court-approved", "government certified", "regulatory approved",
            "100% authentic", "permanently tamper-proof", "绝对真实", "永久防篡改", "公式認定"
        ] {
            XCTAssertFalse(combined.contains(prohibited), prohibited)
        }
    }

    func testPurchaseStateMachine() {
        var machine = TipPurchaseStateMachine()
        XCTAssertEqual(machine.state, .idle)
        XCTAssertTrue(machine.beginLoading())
        XCTAssertTrue(machine.isBusy)
        XCTAssertFalse(machine.beginLoading())
        machine.finishLoading(hasProducts: true)
        XCTAssertEqual(machine.state, .ready)
        XCTAssertTrue(machine.beginPurchase())
        XCTAssertFalse(machine.beginPurchase())
        machine.markPending()
        XCTAssertEqual(machine.state, .pending)
        XCTAssertTrue(machine.isBusy)
        machine.markSucceeded()
        XCTAssertEqual(machine.state, .succeeded)
        XCTAssertFalse(machine.isBusy)

        machine = TipPurchaseStateMachine()
        _ = machine.beginLoading()
        machine.finishLoading(hasProducts: true)
        _ = machine.beginPurchase()
        machine.markSucceeded()
        XCTAssertEqual(machine.state, .succeeded)
        XCTAssertTrue(machine.beginPurchase())
        machine.markCancelled()
        XCTAssertEqual(machine.state, .cancelled)
        XCTAssertTrue(machine.beginPurchase())
        machine.markFailed()
        XCTAssertEqual(machine.state, .failed)
    }

    func testLocalizationParity() throws {
        XCTAssertEqual(try localizationKeys("en"), try localizationKeys("ko"))
        XCTAssertEqual(try localizationKeys("en"), try localizationKeys("zh-Hans"))
    }

    func testPhotoAccessibility() throws {
        let camera = try source("Sources/Features/Camera/Views/CameraView.swift")
        for forbidden in ["\"Photo\"", "\"Saving…\"", "\"Saved\"", "\"Failed\"", "\"Capture photo evidence\"", "\"Captures and saves still-photo evidence\""] {
            XCTAssertFalse(camera.contains(forbidden))
        }
        XCTAssertTrue(camera.contains("ProvikaStrings.Localizable.Camera.PhotoEvidence"))
        XCTAssertTrue(camera.contains("capturePhotoEvidenceButton"))
    }

    func testSupportAccessibility() throws {
        let support = try source("Sources/Features/Settings/Views/SupportDeveloperView.swift")
        XCTAssertTrue(support.contains("tipPurchase.\\(product.id)"))
        XCTAssertTrue(support.contains(".disabled(isDisabled)"))
        XCTAssertTrue(support.contains("store.isBusy"))
        XCTAssertTrue(support.contains(".accessibilityLabel(product.displayName)"))
        XCTAssertTrue(support.contains(".accessibilityHint("))
        XCTAssertTrue(support.contains(".accessibilityValue("))
        XCTAssertTrue(support.contains("Purchase.Accessibility.pending"))
        XCTAssertFalse(support.contains(".font(.system(size:"))
    }

    func testPurchaseErrorsAndLogsAreBounded() throws {
        let store = try source("Sources/Core/Purchase/TipStore.swift")
        XCTAssertFalse(store.contains("localizedDescription"))
        XCTAssertFalse(store.contains("transaction.jwsRepresentation"))
        XCTAssertFalse(store.contains("receipt"))
        XCTAssertTrue(store.contains("Tip product loading failed"))
        XCTAssertTrue(store.contains("Tip purchase failed"))
        XCTAssertTrue(store.contains("Support.Error.generic"))
    }

    private func repositoryURL(_ relativePath: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
    }

    private func source(_ relativePath: String) throws -> String {
        try String(contentsOf: repositoryURL(relativePath), encoding: .utf8)
    }

    private func files(withExtension fileExtension: String) throws -> [URL] {
        let root = repositoryURL("")
        let enumerator = try XCTUnwrap(
            FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
        )
        return enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == fileExtension }
    }

    private func localizationKeys(_ locale: String) throws -> Set<String> {
        let data = try Data(contentsOf: repositoryURL("Resources/Localizable.xcstrings"))
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(root["strings"] as? [String: Any])
        return Set(strings.compactMap { key, value in
            guard let entry = value as? [String: Any],
                  let localizations = entry["localizations"] as? [String: Any],
                  localizations[locale] != nil else { return nil }
            return key
        })
    }

    private func catalogLocales(path: String, key: String) throws -> Set<String> {
        let data = try Data(contentsOf: repositoryURL(path))
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(root["strings"] as? [String: Any])
        let entry = try XCTUnwrap(strings[key] as? [String: Any])
        return Set((entry["localizations"] as? [String: Any])?.keys ?? Dictionary<String, Any>().keys)
    }
}
