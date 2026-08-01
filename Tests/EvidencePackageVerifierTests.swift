import Foundation
import Security
import XCTest
@testable import Provika

final class EvidencePackageVerifierTests: XCTestCase {
    private let fileManager = FileManager.default
    private var temporaryDirectoryURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryDirectoryURL = fileManager.temporaryDirectory
            .appendingPathComponent("EvidencePackageVerifierTests-\(UUID().uuidString)")
        try fileManager.createDirectory(at: temporaryDirectoryURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fileManager.removeItem(at: temporaryDirectoryURL)
        try super.tearDownWithError()
    }

    func testVerifiesSyntheticLegacyPackage() throws {
        let privateKey = try makeEphemeralPrivateKey()
        let package = try writePackage(signingKey: privateKey)

        XCTAssertEqual(
            EvidencePackageVerifier().verify(mediaURL: package.mediaURL, metadataURL: package.metadataURL),
            .verified
        )
    }

    func testReportsExpectedAndActualHashesAfterOneByteMediaChange() throws {
        let package = try writePackage(signingKey: makeEphemeralPrivateKey())
        let expected = try XCTUnwrap(package.metadata.integrity?.hash)
        try Data([0x00, 0xff, 0x11, 0x41, 0x0a]).write(to: package.mediaURL)
        let actual = try HashCalculator.sha256(of: package.mediaURL)

        XCTAssertEqual(
            EvidencePackageVerifier().verify(mediaURL: package.mediaURL, metadataURL: package.metadataURL),
            .hashMismatch(expected: expected, actual: actual)
        )
    }

    func testRejectsSignatureFromWrongKeyOrWrongSignature() throws {
        let signingKey = try makeEphemeralPrivateKey()
        let package = try writePackage(signingKey: signingKey)
        let metadataWithWrongKey = try package.metadata.replacingIntegrity { integrity in
            RecordingMetadata.IntegrityInfo(
                algorithm: integrity.algorithm,
                hash: integrity.hash,
                signatureAlgorithm: integrity.signatureAlgorithm,
                signature: integrity.signature,
                publicKey: try self.legacyPEM(for: self.makeEphemeralPrivateKey())
            )
        }
        try write(metadata: metadataWithWrongKey, to: package.metadataURL)
        XCTAssertEqual(EvidencePackageVerifier().verify(mediaURL: package.mediaURL, metadataURL: package.metadataURL), .invalidSignature)

        let metadataWithWrongSignature = try package.metadata.replacingIntegrity { integrity in
            RecordingMetadata.IntegrityInfo(
                algorithm: integrity.algorithm,
                hash: integrity.hash,
                signatureAlgorithm: integrity.signatureAlgorithm,
                signature: Data([0x01, 0x02, 0x03]).base64EncodedString(),
                publicKey: integrity.publicKey
            )
        }
        try write(metadata: metadataWithWrongSignature, to: package.metadataURL)
        XCTAssertEqual(EvidencePackageVerifier().verify(mediaURL: package.mediaURL, metadataURL: package.metadataURL), .invalidSignature)
    }

    func testReportsMalformedAndUnsupportedInputs() throws {
        let package = try writePackage(signingKey: makeEphemeralPrivateKey())
        try Data("{not json".utf8).write(to: package.metadataURL)
        XCTAssertEqual(EvidencePackageVerifier().verify(mediaURL: package.mediaURL, metadataURL: package.metadataURL), .malformedMetadata)

        var unsupportedVersion = package.metadata
        unsupportedVersion = RecordingMetadata(
            id: unsupportedVersion.id, version: "2.0", app: unsupportedVersion.app, device: unsupportedVersion.device,
            recording: unsupportedVersion.recording, locationTrack: unsupportedVersion.locationTrack,
            integrity: unsupportedVersion.integrity, userNote: unsupportedVersion.userNote, reportedAt: unsupportedVersion.reportedAt
        )
        try write(metadata: unsupportedVersion, to: package.metadataURL)
        XCTAssertEqual(EvidencePackageVerifier().verify(mediaURL: package.mediaURL, metadataURL: package.metadataURL), .unsupportedMetadataVersion("2.0"))

        try assertIntegrityOutcome(.unsupportedHashAlgorithm("SHA-1")) { integrity in
            RecordingMetadata.IntegrityInfo(algorithm: "SHA-1", hash: integrity.hash, signatureAlgorithm: integrity.signatureAlgorithm, signature: integrity.signature, publicKey: integrity.publicKey)
        }
        try assertIntegrityOutcome(.unsupportedSignatureAlgorithm("RSA")) { integrity in
            RecordingMetadata.IntegrityInfo(algorithm: integrity.algorithm, hash: integrity.hash, signatureAlgorithm: "RSA", signature: integrity.signature, publicKey: integrity.publicKey)
        }
        try assertIntegrityOutcome(.malformedSignatureBase64) { integrity in
            RecordingMetadata.IntegrityInfo(algorithm: integrity.algorithm, hash: integrity.hash, signatureAlgorithm: integrity.signatureAlgorithm, signature: "not base64!", publicKey: integrity.publicKey)
        }
        try assertIntegrityOutcome(.invalidEmbeddedPublicKey) { integrity in
            RecordingMetadata.IntegrityInfo(algorithm: integrity.algorithm, hash: integrity.hash, signatureAlgorithm: integrity.signatureAlgorithm, signature: integrity.signature, publicKey: "-----BEGIN PUBLIC KEY-----\nAAAA\n-----END PUBLIC KEY-----")
        }
    }

    func testReportsMissingUnreadableAndIncompleteInputs() throws {
        let package = try writePackage(signingKey: makeEphemeralPrivateKey())
        let verifier = EvidencePackageVerifier()
        XCTAssertEqual(verifier.verify(mediaURL: temporaryDirectoryURL.appendingPathComponent("missing.mov"), metadataURL: package.metadataURL), .missingMedia)
        XCTAssertEqual(verifier.verify(mediaURL: package.mediaURL, metadataURL: temporaryDirectoryURL.appendingPathComponent("missing.json")), .missingMetadata)
        XCTAssertEqual(verifier.verify(mediaURL: temporaryDirectoryURL, metadataURL: package.metadataURL), .unreadableMedia)
        XCTAssertEqual(verifier.verify(mediaURL: package.mediaURL, metadataURL: temporaryDirectoryURL), .unreadableMetadata)

        var withoutIntegrity = package.metadata
        withoutIntegrity.integrity = nil
        try write(metadata: withoutIntegrity, to: package.metadataURL)
        XCTAssertEqual(verifier.verify(mediaURL: package.mediaURL, metadataURL: package.metadataURL), .missingIntegrity)

        try assertIntegrityOutcome(.missingSignatureFields) { integrity in
            RecordingMetadata.IntegrityInfo(algorithm: integrity.algorithm, hash: integrity.hash, signatureAlgorithm: nil, signature: nil, publicKey: nil)
        }
        try assertIntegrityOutcome(.partialSignatureFields) { integrity in
            RecordingMetadata.IntegrityInfo(algorithm: integrity.algorithm, hash: integrity.hash, signatureAlgorithm: integrity.signatureAlgorithm, signature: nil, publicKey: integrity.publicKey)
        }
    }

    private func assertIntegrityOutcome(
        _ expected: EvidencePackageVerifier.Outcome,
        transform: (RecordingMetadata.IntegrityInfo) throws -> RecordingMetadata.IntegrityInfo
    ) throws {
        let package = try writePackage(signingKey: makeEphemeralPrivateKey())
        let metadata = try package.metadata.replacingIntegrity(transform)
        try write(metadata: metadata, to: package.metadataURL)
        XCTAssertEqual(EvidencePackageVerifier().verify(mediaURL: package.mediaURL, metadataURL: package.metadataURL), expected)
    }

    private func writePackage(signingKey: SecKey) throws -> (mediaURL: URL, metadataURL: URL, metadata: RecordingMetadata) {
        let mediaURL = temporaryDirectoryURL.appendingPathComponent("\(UUID().uuidString).mov")
        let metadataURL = temporaryDirectoryURL.appendingPathComponent("\(UUID().uuidString).json")
        try Data([0x00, 0xff, 0x10, 0x41, 0x0a]).write(to: mediaURL)
        let hash = try HashCalculator.sha256(of: mediaURL)
        let signature = try sign(hash: hash, with: signingKey)
        let metadata = makeMetadata(integrity: .init(algorithm: "SHA-256", hash: hash, signatureAlgorithm: "ECDSA-P256-SHA256", signature: signature.base64EncodedString(), publicKey: try legacyPEM(for: signingKey)))
        try write(metadata: metadata, to: metadataURL)
        return (mediaURL, metadataURL, metadata)
    }

    private func makeMetadata(integrity: RecordingMetadata.IntegrityInfo?) -> RecordingMetadata {
        RecordingMetadata(
            id: UUID().uuidString, version: "1.0",
            app: .init(name: "Provika", version: "1.0", build: "1"),
            device: .init(model: "Test", systemVersion: "iOS", identifierForVendor: nil),
            recording: .init(startedAt: "2026-01-01T00:00:00Z", endedAt: nil, duration: nil, resolution: "1x1", frameRate: 1, codec: "test"),
            locationTrack: [], integrity: integrity, userNote: nil, reportedAt: nil
        )
    }

    private func write(metadata: RecordingMetadata, to url: URL) throws {
        try JSONEncoder().encode(metadata).write(to: url)
    }

    private func makeEphemeralPrivateKey() throws -> SecKey {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecPrivateKeyAttrs as String: [kSecAttrIsPermanent as String: false]
        ]
        guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, nil) else {
            throw NSError(domain: "EvidencePackageVerifierTests", code: 1)
        }
        return key
    }

    private func legacyPEM(for privateKey: SecKey) throws -> String {
        guard let publicKey = SecKeyCopyPublicKey(privateKey),
              let data = SecKeyCopyExternalRepresentation(publicKey, nil) else {
            throw NSError(domain: "EvidencePackageVerifierTests", code: 2)
        }
        return "-----BEGIN PUBLIC KEY-----\n\((data as Data).base64EncodedString())\n-----END PUBLIC KEY-----"
    }

    private func sign(hash: String, with privateKey: SecKey) throws -> Data {
        guard let signature = SecKeyCreateSignature(privateKey, .ecdsaSignatureMessageX962SHA256, Data(hash.utf8) as CFData, nil) else {
            throw NSError(domain: "EvidencePackageVerifierTests", code: 3)
        }
        return signature as Data
    }
}

private extension RecordingMetadata {
    func replacingIntegrity(
        _ transform: (IntegrityInfo) throws -> IntegrityInfo
    ) throws -> RecordingMetadata {
        guard let integrity else { throw NSError(domain: "EvidencePackageVerifierTests", code: 4) }
        return RecordingMetadata(
            id: id, version: version, app: app, device: device, recording: recording,
            locationTrack: locationTrack, integrity: try transform(integrity), userNote: userNote, reportedAt: reportedAt
        )
    }
}
