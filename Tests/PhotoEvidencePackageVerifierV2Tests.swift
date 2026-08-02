import Foundation
import Security
import XCTest
@testable import Provika

final class PhotoEvidencePackageVerifierV2Tests: XCTestCase {
    func testValidFinalizerPackageIsValid() throws {
        let package = try makeFinalizerPackage()
        defer { remove(package.root) }
        XCTAssertEqual(PhotoEvidencePackageVerifierV2().verify(packageDirectory: package.directory), .valid)
    }

    func testFrozenClaimFixturePackageIsValid() throws {
        let fixture = try fixtureClaim()
        let package = try makeFinalizerPackage(claim: fixture)
        defer { remove(package.root) }
        XCTAssertEqual(PhotoEvidencePackageVerifierV2().verify(packageDirectory: package.directory), .valid)
    }

    func testOriginalMediaTamperIsDetected() throws {
        let package = try makeFinalizerPackage()
        defer { remove(package.root) }
        try Data([0]).write(to: package.media)
        XCTAssertEqual(PhotoEvidencePackageVerifierV2().verify(packageDirectory: package.directory), .originalMediaDigestMismatch)
    }

    func testClaimByteTamperIsDetected() throws {
        let package = try makeFinalizerPackage()
        defer { remove(package.root) }
        try replaceFirst("Provika", with: "Xrovika", in: package.claim)
        XCTAssertEqual(PhotoEvidencePackageVerifierV2().verify(packageDirectory: package.directory), .claimDigestMismatch)
    }

    func testClaimFieldTamperIsDetected() throws {
        let package = try makeFinalizerPackage()
        defer { remove(package.root) }
        var object = try object(at: package.claim)
        var app = try XCTUnwrap(object["app"] as? [String: Any])
        app["build"] = "201"
        object["app"] = app
        try write(object, to: package.claim)
        XCTAssertEqual(PhotoEvidencePackageVerifierV2().verify(packageDirectory: package.directory), .claimDigestMismatch)
    }

    func testSignatureTamperIsInvalid() throws {
        let package = try makeFinalizerPackage()
        defer { remove(package.root) }
        var object = try object(at: package.signature)
        var signature = try XCTUnwrap(object["signature"] as? [String: Any])
        signature["value"] = Data([1, 2, 3]).base64EncodedString()
        object["signature"] = signature
        try write(object, to: package.signature)
        XCTAssertEqual(PhotoEvidencePackageVerifierV2().verify(packageDirectory: package.directory), .invalidSignature)
    }

    func testPublicKeyReplacementIsInvalid() throws {
        let package = try makeFinalizerPackage()
        defer { remove(package.root) }
        var object = try object(at: package.signature)
        var publicKey = try XCTUnwrap(object["publicKey"] as? [String: Any])
        publicKey["value"] = try publicKeyData(for: makePrivateKey()).base64EncodedString()
        object["publicKey"] = publicKey
        try write(object, to: package.signature)
        XCTAssertEqual(PhotoEvidencePackageVerifierV2().verify(packageDirectory: package.directory), .invalidSignature)
    }

    func testMalformedPublicKey() throws {
        let package = try makeFinalizerPackage()
        defer { remove(package.root) }
        var object = try object(at: package.signature)
        var publicKey = try XCTUnwrap(object["publicKey"] as? [String: Any])
        publicKey["value"] = "not-base64"
        object["publicKey"] = publicKey
        try write(object, to: package.signature)
        XCTAssertEqual(PhotoEvidencePackageVerifierV2().verify(packageDirectory: package.directory), .malformedPublicKey)
    }

    func testMissingArtifacts() throws {
        let package = try makeFinalizerPackage()
        defer { remove(package.root) }
        try FileManager.default.removeItem(at: package.signature)
        XCTAssertEqual(PhotoEvidencePackageVerifierV2().verify(packageDirectory: package.directory), .missingRequiredArtifact)
    }

    func testMalformedClaim() throws {
        let package = try makeFinalizerPackage()
        defer { remove(package.root) }
        try Data("{".utf8).write(to: package.claim)
        XCTAssertEqual(PhotoEvidencePackageVerifierV2().verify(packageDirectory: package.directory), .malformedClaim)
    }

    func testMalformedSignatureEnvelope() throws {
        let package = try makeFinalizerPackage()
        defer { remove(package.root) }
        try Data("{".utf8).write(to: package.signature)
        XCTAssertEqual(PhotoEvidencePackageVerifierV2().verify(packageDirectory: package.directory), .malformedSignatureEnvelope)
    }

    func testUnsupportedSchemaVersion() throws {
        let package = try makeFinalizerPackage()
        defer { remove(package.root) }
        var object = try object(at: package.claim)
        object["schemaVersion"] = "3.0"
        try write(object, to: package.claim)
        XCTAssertEqual(PhotoEvidencePackageVerifierV2().verify(packageDirectory: package.directory), .unsupportedSchemaVersion)
    }

    func testUnsupportedSignatureAlgorithm() throws {
        let package = try makeFinalizerPackage()
        defer { remove(package.root) }
        var object = try object(at: package.signature)
        var signature = try XCTUnwrap(object["signature"] as? [String: Any])
        signature["algorithm"] = "rsa"
        object["signature"] = signature
        try write(object, to: package.signature)
        XCTAssertEqual(PhotoEvidencePackageVerifierV2().verify(packageDirectory: package.directory), .unsupportedSignatureAlgorithm)
    }

    func testEmptyPackage() throws {
        let root = try root()
        defer { remove(root) }
        XCTAssertEqual(PhotoEvidencePackageVerifierV2().verify(packageDirectory: root), .missingRequiredArtifact)
    }

    func testRegularFileInput() throws {
        let root = try root()
        defer { remove(root) }
        let file = root.appendingPathComponent("file")
        try Data().write(to: file)
        XCTAssertEqual(PhotoEvidencePackageVerifierV2().verify(packageDirectory: file), .unexpectedArtifactType)
    }

    func testPackageBytesRemainUnchanged() throws {
        let package = try makeFinalizerPackage()
        defer { remove(package.root) }
        let before = try packageInventory(in: package.directory)
        XCTAssertEqual(PhotoEvidencePackageVerifierV2().verify(packageDirectory: package.directory), .valid)
        XCTAssertEqual(try packageInventory(in: package.directory), before)
    }

    func testWorksWithoutKeychain() throws {
        let package = try makeFinalizerPackage()
        defer { remove(package.root) }
        XCTAssertEqual(PhotoEvidencePackageVerifierV2().verify(packageDirectory: package.directory), .valid)
    }

    func testWorksOffline() throws {
        let package = try makeFinalizerPackage()
        defer { remove(package.root) }
        XCTAssertEqual(PhotoEvidencePackageVerifierV2().verify(packageDirectory: package.directory), .valid)
    }

    func testRepeatedVerificationIsDeterministic() throws {
        let package = try makeFinalizerPackage()
        defer { remove(package.root) }
        let verifier = PhotoEvidencePackageVerifierV2()
        XCTAssertEqual(verifier.verify(packageDirectory: package.directory), verifier.verify(packageDirectory: package.directory))
    }

    func testUnknownExtraFilePolicy() throws {
        let package = try makeFinalizerPackage()
        defer { remove(package.root) }
        try Data("extra".utf8).write(to: package.directory.appendingPathComponent("extra.txt"))
        XCTAssertEqual(PhotoEvidencePackageVerifierV2().verify(packageDirectory: package.directory), .unexpectedArtifactType)
    }

    private func makeFinalizerPackage(claim: PhotoEvidenceClaimV2? = nil) throws -> (root: URL, directory: URL, media: URL, claim: URL, signature: URL) {
        let temporaryRoot = try root()
        let privateKey = try makePrivateKey()
        let package = temporaryRoot.appendingPathComponent("package", isDirectory: true)
        let photo = temporaryRoot.appendingPathComponent("input.jpg")
        try Data([0xff, 0xd8, 0x00, 0x01, 0xff, 0xd9]).write(to: photo)
        let evidenceClaim = claim ?? PhotoEvidenceClaimV2(
            packageID: UUID(),
            media: .init(fileName: "original.jpg", mediaType: "image/jpeg", pixelWidth: 2, pixelHeight: 1, sha256: String(repeating: "0", count: 64)),
            capture: .init(deviceTime: "2026-01-02T03:04:05.678Z"),
            app: .init(name: "Provika", version: "2.0.0", build: "200"),
            device: .init(model: "Synthetic iPhone", systemVersion: "iOS 18.0")
        )
        try PhotoEvidencePackageFinalizerV2(
            signer: EphemeralSigner(privateKey: privateKey),
            publicKeyProvider: EphemeralPublicKeyProvider(privateKey: privateKey)
        ).finalize(originalPhotoURL: photo, claim: evidenceClaim, packageDirectory: package)
        return (temporaryRoot, package, package.appendingPathComponent(evidenceClaim.media.fileName), package.appendingPathComponent("claim.json"), package.appendingPathComponent("signature.json"))
    }

    private func fixtureClaim() throws -> PhotoEvidenceClaimV2 {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/photo-evidence-claim-v2.json")
        return try JSONDecoder().decode(PhotoEvidenceClaimV2.self, from: Data(contentsOf: url))
    }

    private func makePrivateKey() throws -> SecKey {
        let attributes: [String: Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom, kSecAttrKeySizeInBits as String: 256, kSecPrivateKeyAttrs as String: [kSecAttrIsPermanent as String: false]]
        guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, nil) else { throw NSError(domain: "PhotoEvidencePackageVerifierV2Tests", code: 1) }
        return key
    }

    private func publicKeyData(for privateKey: SecKey) throws -> Data {
        guard let publicKey = SecKeyCopyPublicKey(privateKey), let data = SecKeyCopyExternalRepresentation(publicKey, nil) else { throw NSError(domain: "PhotoEvidencePackageVerifierV2Tests", code: 2) }
        return data as Data
    }

    private func root() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("PhotoEvidencePackageVerifierV2Tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func remove(_ url: URL) { try? FileManager.default.removeItem(at: url) }

    private func object(at url: URL) throws -> [String: Any] { try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]) }
    private func write(_ object: [String: Any], to url: URL) throws { try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]).write(to: url) }
    private func replaceFirst(_ old: String, with new: String, in url: URL) throws {
        let data = try Data(contentsOf: url)
        let string = try XCTUnwrap(String(data: data, encoding: .utf8))
        let range = try XCTUnwrap(string.range(of: old))
        let replacement = string.replacingCharacters(in: range, with: new)
        try XCTUnwrap(replacement.data(using: .utf8)).write(to: url)
    }
    private func packageInventory(in directory: URL) throws -> [String: Data] {
        try FileManager.default.contentsOfDirectory(atPath: directory.path).reduce(into: [:]) { result, name in result[name] = try Data(contentsOf: directory.appendingPathComponent(name)) }
    }
}

private struct EphemeralSigner: PhotoEvidenceSigningV2 {
    let privateKey: SecKey
    func sign(_ data: Data) throws -> Data {
        guard let signature = SecKeyCreateSignature(privateKey, .ecdsaSignatureMessageX962SHA256, data as CFData, nil) else { throw NSError(domain: "PhotoEvidencePackageVerifierV2Tests", code: 3) }
        return signature as Data
    }
}

private struct EphemeralPublicKeyProvider: PhotoEvidencePublicKeyProvidingV2 {
    let privateKey: SecKey
    func publicKeyData() throws -> Data {
        guard let publicKey = SecKeyCopyPublicKey(privateKey), let data = SecKeyCopyExternalRepresentation(publicKey, nil) else { throw NSError(domain: "PhotoEvidencePackageVerifierV2Tests", code: 4) }
        return data as Data
    }
}
