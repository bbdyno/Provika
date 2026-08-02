import Foundation
import Security
import XCTest
@testable import Provika

final class LocaleNeutralEvidenceCoreTests: XCTestCase {
    func testFrozenFixtureCoreIsByteIdenticalAcrossLocalesAndVerifiesOffline() throws {
        let fixtureData = try Data(contentsOf: fixtureURL())
        let fixtureClaim = try JSONDecoder().decode(PhotoEvidenceClaimV2.self, from: fixtureData)

        let locales = ["ko_KR", "en_US", "zh_Hans_CN"]
        let results = try locales.map { locale in
            try withPreferredLocale(locale) {
                let decodedFixture = try JSONDecoder().decode(PhotoEvidenceClaimV2.self, from: fixtureData)
                let package = try finalizeFixtureClaim(decodedFixture)
                return (claim: decodedFixture, package: package)
            }
        }
        let packages = results.map { $0.package }
        defer { packages.forEach { try? FileManager.default.removeItem(at: $0.root) } }

        XCTAssertEqual(results.map { $0.claim }, Array(repeating: fixtureClaim, count: locales.count))
        let claimData = try packages.map { try Data(contentsOf: $0.claimURL) }
        let claimHashes = claimData.map(HashCalculator.sha256(of:))
        XCTAssertEqual(claimData, Array(repeating: claimData[0], count: locales.count))
        XCTAssertEqual(claimHashes, Array(repeating: claimHashes[0], count: locales.count))

        for package in packages {
            let claim = try JSONDecoder().decode(PhotoEvidenceClaimV2.self, from: Data(contentsOf: package.claimURL))
            XCTAssertEqual(claim.schemaVersion, "2.0")
            XCTAssertEqual(claim.capture.deviceTime, "2026-01-02T03:04:05.678Z")
            XCTAssertEqual(claim.capture.timeSource, "device-clock")
            XCTAssertEqual(claim.app.name, "Provika")
            XCTAssertEqual(claim.app.version, fixtureClaim.app.version)
            XCTAssertEqual(claim.app.build, fixtureClaim.app.build)
            XCTAssertEqual(claim.media.fileName, "synthetic-photo.jpg")
            XCTAssertEqual(claim.media.mediaType, "image/jpeg")
            XCTAssertEqual(claim.media.pixelWidth, 4032)
            XCTAssertEqual(claim.media.pixelHeight, 3024)
            XCTAssertEqual(claim.location?.source, "core-location-device")
            XCTAssertEqual(claim.location?.lat, 37.5665)
            XCTAssertEqual(claim.location?.lng, 126.978)
            XCTAssertEqual(claim.location?.horizontalAccuracyMeters, 4.5)
            XCTAssertEqual(claim.location?.altitudeMeters, 38.2)
            XCTAssertEqual(claim.location?.verticalAccuracyMeters, 6.7)
            XCTAssertEqual(claim.location?.headingDegrees, 91.25)
            XCTAssertEqual(claim.location?.speedMetersPerSecond, 12.3)
            // Signed Core excludes reverse-geocoded presentation values while
            // preserving user-authored context exactly as entered.
            XCTAssertEqual(claim.context, fixtureClaim.context)
            XCTAssertEqual(PhotoEvidencePackageVerifierV2().verify(packageDirectory: package.directory), .valid)
        }
    }

    func testCanonicalizationConvertsOffsetCaptureTimeToFixedUTCWithoutChangingUserContext() throws {
        let context = PhotoEvidenceClaimV2.Context(
            projectID: "현장-001",
            projectName: "서울 현장",
            note: "사용자가 입력한 note / 用户输入",
            organizationName: "Provika 한국"
        )
        let original = PhotoEvidenceClaimV2(
            packageID: UUID(uuidString: "A0B1C2D3-E4F5-4678-9ABC-DEF012345678")!,
            media: .init(fileName: "original.jpg", mediaType: "image/jpeg", pixelWidth: 2, pixelHeight: 1, sha256: String(repeating: "0", count: 64)),
            capture: .init(deviceTime: "2026-01-02T12:04:05.678+09:00"),
            app: .init(name: "프로비카", version: "2.0.0", build: "200"),
            device: .init(model: "Synthetic iPhone", systemVersion: "iOS 18.0"),
            context: context
        )

        let frozen = try EvidenceCoreCanonicalizationV2.frozenClaim(replacingMediaDigest: String(repeating: "a", count: 64), in: original)
        XCTAssertEqual(frozen.capture.deviceTime, "2026-01-02T03:04:05.678Z")
        XCTAssertEqual(frozen.app.name, "Provika")
        XCTAssertEqual(frozen.app.version, original.app.version)
        XCTAssertEqual(frozen.app.build, original.app.build)
        XCTAssertEqual(frozen.context, context)
    }

    private func finalizeFixtureClaim(_ claim: PhotoEvidenceClaimV2) throws -> (root: URL, directory: URL, claimURL: URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LocaleNeutralEvidenceCoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let photo = root.appendingPathComponent("input.jpg")
        try Data([0xff, 0xd8, 0x00, 0x01, 0xff, 0xd9]).write(to: photo)
        let privateKey = try privateKey()
        let directory = root.appendingPathComponent("package", isDirectory: true)
        try PhotoEvidencePackageFinalizerV2(
            signer: LocaleNeutralSigner(privateKey: privateKey),
            publicKeyProvider: LocaleNeutralPublicKeyProvider(privateKey: privateKey)
        ).finalize(originalPhotoURL: photo, claim: claim, packageDirectory: directory)
        return (root, directory, directory.appendingPathComponent("claim.json"))
    }

    private func fixtureURL() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/photo-evidence-claim-v2.json")
    }

    private func withPreferredLocale<T>(_ identifier: String, operation: () throws -> T) throws -> T {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: "AppleLanguages")
        defaults.set([identifier], forKey: "AppleLanguages")
        defer {
            if let previous { defaults.set(previous, forKey: "AppleLanguages") }
            else { defaults.removeObject(forKey: "AppleLanguages") }
        }
        return try operation()
    }

    private func privateKey() throws -> SecKey {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecPrivateKeyAttrs as String: [kSecAttrIsPermanent as String: false]
        ]
        guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, nil) else {
            throw NSError(domain: "LocaleNeutralEvidenceCoreTests", code: 1)
        }
        return key
    }
}

private struct LocaleNeutralSigner: PhotoEvidenceSigningV2 {
    let privateKey: SecKey

    func sign(_ data: Data) throws -> Data {
        guard let signature = SecKeyCreateSignature(privateKey, .ecdsaSignatureMessageX962SHA256, data as CFData, nil) else {
            throw NSError(domain: "LocaleNeutralEvidenceCoreTests", code: 2)
        }
        return signature as Data
    }
}

private struct LocaleNeutralPublicKeyProvider: PhotoEvidencePublicKeyProvidingV2 {
    let privateKey: SecKey

    func publicKeyData() throws -> Data {
        guard let publicKey = SecKeyCopyPublicKey(privateKey), let data = SecKeyCopyExternalRepresentation(publicKey, nil) else {
            throw NSError(domain: "LocaleNeutralEvidenceCoreTests", code: 3)
        }
        return data as Data
    }
}
