import Foundation
import Security
import XCTest
@testable import Provika

final class LegacyVideoCharacterizationTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LegacyVideoCharacterizationTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    func testDocumentsRecordingsMOVJSONPairingAndLegacyLinkageRemainObservable() throws {
        let storage = try source("Sources/Core/Storage/FileStorage.swift")
        let model = try source("Sources/Core/Storage/Models/Recording.swift")
        let metadata = try source("Sources/Core/Storage/RecordingMetadata.swift")
        let detail = try source("Sources/Features/Gallery/Views/VideoDetailView.swift")

        XCTAssertTrue(storage.contains("documentDirectory")) // Documents
        XCTAssertTrue(storage.contains("Recordings"))
        XCTAssertTrue(storage.contains("deleteRecording")) // deletion compatibility
        XCTAssertTrue(model.contains("@Model")) // SwiftData Recording linkage
        XCTAssertTrue(model.contains("sidecarURLString"))
        XCTAssertTrue(metadata.contains("version: \"1.0\"")) // RecordingMetadata v1
        XCTAssertTrue(detail.contains("ShareLink"))
        XCTAssertTrue(detail.contains("item: recording.fileURL")) // legacy ShareLink is video-only .mov
        XCTAssertFalse(detail.contains("item: recording.sidecarURL")) // JSON is not shared by this legacy UI
    }

    func testSHA256UTF8SignatureVectorVerifiesOfflineAndDetectsMutation() throws {
        // Legacy behavior: SHA-256 lowercase hex is signed as UTF8 bytes; publicKey and
        // signature are embedded so EvidencePackageVerifier is Keychain-free and offline.
        let privateKey = try makePrivateKey()
        let mediaURL = temporaryDirectory.appendingPathComponent("legacy.mov")
        let metadataURL = temporaryDirectory.appendingPathComponent("legacy.json")
        try Data([0x00, 0xff, 0x10, 0x41, 0x0a]).write(to: mediaURL)

        let hash = try HashCalculator.sha256(of: mediaURL)
        XCTAssertEqual(hash, hash.lowercased())
        let signature = try sign(hash: hash, with: privateKey)
        let metadata = RecordingMetadata(
            id: "legacy-vector", version: "1.0",
            app: .init(name: "Provika", version: "1.0", build: "1"),
            device: .init(model: "Test", systemVersion: "iOS", identifierForVendor: nil),
            recording: .init(startedAt: "2026-01-01T00:00:00Z", endedAt: nil, duration: nil, resolution: "1x1", frameRate: 1, codec: "test"),
            locationTrack: [],
            integrity: .init(
                algorithm: "SHA-256", hash: hash,
                signatureAlgorithm: "ECDSA-P256-SHA256",
                signature: signature.base64EncodedString(), publicKey: try publicKeyPEM(for: privateKey)
            ),
            userNote: nil, reportedAt: nil
        )
        try JSONEncoder().encode(metadata).write(to: metadataURL)

        let verifier = EvidencePackageVerifier()
        XCTAssertEqual(verifier.verify(mediaURL: mediaURL, metadataURL: metadataURL), .verified)
        try Data([0x00, 0xff, 0x10, 0x41, 0x0b]).write(to: mediaURL)
        let actual = try HashCalculator.sha256(of: mediaURL)
        XCTAssertEqual(verifier.verify(mediaURL: mediaURL, metadataURL: metadataURL), .hashMismatch(expected: hash, actual: actual))
    }

    func testBehaviorMatrixKeepsExternalOutcomesAsProofGaps() throws {
        let data = try Data(contentsOf: repositoryURL("Tests/Fixtures/legacy-video-behavior-matrix-v1.json"))
        let matrix = try JSONDecoder().decode(BehaviorMatrix.self, from: data)
        XCTAssertEqual(matrix.schemaVersion, "1.0")
        XCTAssertGreaterThanOrEqual(matrix.scenarios.count, 9)
        XCTAssertTrue(matrix.scenarios.contains { $0.status == "external-proof-gap" })
        XCTAssertTrue(matrix.scenarios.allSatisfy {
            ["automated-observed", "source-observed", "external-proof-gap"].contains($0.status)
        })
    }

    private func makePrivateKey() throws -> SecKey {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecPrivateKeyAttrs as String: [kSecAttrIsPermanent as String: false]
        ]
        guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, nil) else {
            throw NSError(domain: "LegacyVideoCharacterizationTests", code: 1)
        }
        return key
    }

    private func publicKeyPEM(for privateKey: SecKey) throws -> String {
        guard let publicKey = SecKeyCopyPublicKey(privateKey),
              let data = SecKeyCopyExternalRepresentation(publicKey, nil) else {
            throw NSError(domain: "LegacyVideoCharacterizationTests", code: 2)
        }
        return "-----BEGIN PUBLIC KEY-----\n\((data as Data).base64EncodedString())\n-----END PUBLIC KEY-----"
    }

    private func sign(hash: String, with privateKey: SecKey) throws -> Data {
        guard let signature = SecKeyCreateSignature(
            privateKey, .ecdsaSignatureMessageX962SHA256, Data(hash.utf8) as CFData, nil
        ) else { throw NSError(domain: "LegacyVideoCharacterizationTests", code: 3) }
        return signature as Data
    }

    private func source(_ relativePath: String) throws -> String {
        try String(contentsOf: repositoryURL(relativePath), encoding: .utf8)
    }

    private func repositoryURL(_ relativePath: String) -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(relativePath)
    }
}

private struct BehaviorMatrix: Decodable {
    struct Scenario: Decodable {
        let id: String
        let status: String
        let provenance: String
        let observedOutcome: String
    }
    let schemaVersion: String
    let scenarios: [Scenario]
}
