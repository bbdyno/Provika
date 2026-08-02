import Foundation
import Security
import XCTest
@testable import Provika

final class VideoEvidencePackageVerifierV2Tests: XCTestCase {
    func testGoldenVerification() throws {
        let p = try makePackage(); defer { remove(p.root) }
        XCTAssertEqual(verify(p), .valid)
    }
    func testTamperedMedia() throws {
        let p = try makePackage(); defer { remove(p.root) }
        try Data("mutated".utf8).write(to: p.media)
        XCTAssertEqual(verify(p), .mediaHashMismatch)
    }
    func testMutatedClaim() throws {
        let p = try makePackage(); defer { remove(p.root) }
        let original = try JSONDecoder().decode(VideoEvidenceClaimV2.self, from: Data(contentsOf: p.claim))
        let changed = VideoEvidenceClaimV2(
            packageID: original.packageID,
            media: original.media,
            capture: original.capture,
            app: .init(name: original.app.name, version: original.app.version, build: "changed"),
            device: original.device,
            finalization: original.finalization,
            videoTrack: original.videoTrack,
            audioTrack: original.audioTrack,
            audioIncluded: original.audioIncluded,
            microphoneAuthorization: original.microphoneAuthorization,
            silentRecordingDecision: original.silentRecordingDecision
        )
        try changed.canonicalData().write(to: p.claim)
        XCTAssertEqual(verify(p), .claimHashMismatch)
    }
    func testMutatedSignature() throws {
        let p = try makePackage(); defer { remove(p.root) }
        var value = try json(p.signature)
        var signature = try XCTUnwrap(value["signature"] as? [String: Any])
        signature["value"] = Data([1, 2, 3]).base64EncodedString(); value["signature"] = signature
        try write(value, p.signature)
        XCTAssertEqual(verify(p), .invalidSignature)
    }
    func testMalformedKeyAndSignature() throws {
        let p = try makePackage(); defer { remove(p.root) }
        var value = try json(p.signature)
        var key = try XCTUnwrap(value["publicKey"] as? [String: Any]); key["value"] = "not-base64"; value["publicKey"] = key
        try write(value, p.signature)
        XCTAssertEqual(verify(p), .malformedKey)

        let malformed = try makePackage(); defer { remove(malformed.root) }
        var envelope = try json(malformed.signature)
        var signature = try XCTUnwrap(envelope["signature"] as? [String: Any])
        signature["value"] = "not-base64"; envelope["signature"] = signature
        try write(envelope, malformed.signature)
        XCTAssertEqual(verify(malformed), .malformedSignature)
    }
    func testMutatedManifest() throws {
        let p = try makePackage(); defer { remove(p.root) }
        var value = try json(p.manifest)
        var artifacts = try XCTUnwrap(value["artifacts"] as? [[String: Any]])
        artifacts[0]["sha256"] = String(repeating: "f", count: 64); value["artifacts"] = artifacts
        try write(value, p.manifest)
        XCTAssertEqual(verify(p), .manifestMismatch)
    }
    func testMissingRequiredTrack() throws {
        let p = try makePackage(); defer { remove(p.root) }
        var value = try json(p.claim); value["audioIncluded"] = true; value["audioTrack"] = NSNull()
        try write(value, p.claim)
        XCTAssertEqual(verify(p), .trackPolicyFailure)
    }
    func testIncompletePackage() throws {
        let p = try makePackage(); defer { remove(p.root) }
        try FileManager.default.removeItem(at: p.signature)
        XCTAssertEqual(verify(p), .missingFile("signature.json"))
    }
    func testOfflineVerification() throws {
        let p = try makePackage(); defer { remove(p.root) }
        XCTAssertEqual(verify(p), .valid)
    }
    func testLocaleMatrix() throws {
        let p = try makePackage(); defer { remove(p.root) }
        let results = ["ko_KR", "en_US", "zh_Hans_CN"].map { _ in verify(p) }
        XCTAssertEqual(results, [.valid, .valid, .valid])
    }
    func testRequiredTrackPolicy() throws {
        let p = try makePackage(); defer { remove(p.root) }
        XCTAssertEqual(
            VideoEvidencePackageVerifierV2().verify(packageDirectory: p.directory, policy: .init(requiredTracks: ["audio", "video"])),
            .trackPolicyFailure
        )
    }
    func testUnsupportedVersionAndAlgorithm() throws {
        let version = try makePackage(); defer { remove(version.root) }
        var claim = try json(version.claim); claim["schemaVersion"] = "3.0"; try write(claim, version.claim)
        XCTAssertEqual(verify(version), .unsupportedVersion("3.0"))

        let algorithm = try makePackage(); defer { remove(algorithm.root) }
        var envelope = try json(algorithm.signature)
        var signature = try XCTUnwrap(envelope["signature"] as? [String: Any])
        signature["algorithm"] = "rsa"; envelope["signature"] = signature; try write(envelope, algorithm.signature)
        XCTAssertEqual(verify(algorithm), .unsupportedAlgorithm("signature"))
    }

    private typealias Package = (root: URL, directory: URL, media: URL, claim: URL, signature: URL, manifest: URL)
    private func verify(_ p: Package) -> VideoEvidencePackageVerificationResultV2 {
        VideoEvidencePackageVerifierV2().verify(packageDirectory: p.directory)
    }
    private func makePackage() throws -> Package {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("VideoVerifierV2Tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("staged.mov")
        try Data([0, 1, 2, 3, 4, 5]).write(to: source)
        let key = try privateKey()
        let package = root.appendingPathComponent("package", isDirectory: true)
        try VideoEvidencePackageFinalizerV2(signer: VerifierSigner(key: key), publicKeyProvider: VerifierPublicKey(key: key))
            .finalize(stagedVideoURL: source, claim: claim(), packageDirectory: package)
        return (root, package, package.appendingPathComponent("original.mov"), package.appendingPathComponent("claim.json"), package.appendingPathComponent("signature.json"), package.appendingPathComponent("manifest.json"))
    }
    private func claim() -> VideoEvidenceClaimV2 {
        .init(
            packageID: UUID(uuidString: "A0B1C2D3-E4F5-4678-9ABC-DEF012345678")!,
            media: .init(fileName: "original.mov", mediaType: "video/quicktime", byteLength: 0, sha256: String(repeating: "0", count: 64)),
            capture: .init(deviceTimeUTC: "2026-01-02T03:04:05.678Z"),
            app: .init(name: "Provika", version: "2.0.0", build: "200"),
            device: .init(model: "Synthetic iPhone", systemVersion: "iOS 18.0"),
            finalization: .init(completedAtUTC: "2026-01-02T03:04:15.678Z"),
            videoTrack: .init(kind: "video", codec: "hvc1", durationMilliseconds: 10_000, width: 1920, height: 1080, channelCount: nil),
            audioTrack: nil,
            audioIncluded: false,
            microphoneAuthorization: .denied,
            silentRecordingDecision: .allowWhenMicrophoneDenied
        )
    }
    private func privateKey() throws -> SecKey {
        let attributes: [String: Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom, kSecAttrKeySizeInBits as String: 256, kSecPrivateKeyAttrs as String: [kSecAttrIsPermanent as String: false]]
        guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, nil) else { throw VerifierTestError.expected }
        return key
    }
    private func json(_ url: URL) throws -> [String: Any] { try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]) }
    private func write(_ object: [String: Any], _ url: URL) throws { try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]).write(to: url) }
    private func remove(_ url: URL) { try? FileManager.default.removeItem(at: url) }
}

private enum VerifierTestError: Error { case expected }
private struct VerifierSigner: PhotoEvidenceSigningV2 {
    let key: SecKey
    func sign(_ data: Data) throws -> Data {
        guard let value = SecKeyCreateSignature(key, .ecdsaSignatureMessageX962SHA256, data as CFData, nil) else { throw VerifierTestError.expected }
        return value as Data
    }
}
private struct VerifierPublicKey: PhotoEvidencePublicKeyProvidingV2 {
    let key: SecKey
    func publicKeyData() throws -> Data {
        guard let publicKey = SecKeyCopyPublicKey(key), let data = SecKeyCopyExternalRepresentation(publicKey, nil) else { throw VerifierTestError.expected }
        return data as Data
    }
}
