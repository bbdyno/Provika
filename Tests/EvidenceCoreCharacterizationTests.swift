import Foundation
import Security
import XCTest
@testable import Provika

final class EvidenceCoreCharacterizationTests: XCTestCase {
    private let fileManager = FileManager.default
    private var temporaryFileURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryFileURL = fileManager.temporaryDirectory
            .appendingPathComponent("EvidenceCoreCharacterizationTests-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        if let temporaryFileURL {
            try? fileManager.removeItem(at: temporaryFileURL)
        }
        try super.tearDownWithError()
    }

    func testSHA256OfExactRawFileBytesMatchesKnownLowercaseHex() throws {
        let rawBytes = Data([0x00, 0xff, 0x10, 0x41, 0x0a])
        try rawBytes.write(to: temporaryFileURL)

        XCTAssertEqual(
            try HashCalculator.sha256(of: temporaryFileURL),
            "72d3c5005e8e96b836e9813faf295a298af795d62bcf989351c655ab36de931f"
        )
    }

    func testSHA256OfMissingFileThrows() {
        XCTAssertThrowsError(try HashCalculator.sha256(of: temporaryFileURL))
    }

    func testVersion1MetadataFixtureDecodesAndRoundTripsSemantically() throws {
        let fixture = try Data(contentsOf: fixtureURL())
        let decoded = try JSONDecoder().decode(RecordingMetadata.self, from: fixture)
        let roundTripped = try JSONDecoder().decode(
            RecordingMetadata.self,
            from: JSONEncoder().encode(decoded)
        )

        XCTAssertEqual(decoded.id, "synthetic-legacy-recording-001")
        XCTAssertEqual(decoded.version, "1.0")
        XCTAssertEqual(decoded.app.name, "Provika")
        XCTAssertEqual(decoded.recording.duration, 12.25)
        XCTAssertEqual(decoded.locationTrack.count, 1)
        XCTAssertEqual(decoded.integrity?.hash, "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef")
        XCTAssertEqual(roundTripped.id, decoded.id)
        XCTAssertEqual(roundTripped.version, decoded.version)
        XCTAssertEqual(roundTripped.app.name, decoded.app.name)
        XCTAssertEqual(roundTripped.app.version, decoded.app.version)
        XCTAssertEqual(roundTripped.app.build, decoded.app.build)
        XCTAssertEqual(roundTripped.device.model, decoded.device.model)
        XCTAssertEqual(roundTripped.device.systemVersion, decoded.device.systemVersion)
        XCTAssertEqual(roundTripped.device.identifierForVendor, decoded.device.identifierForVendor)
        XCTAssertEqual(roundTripped.recording.startedAt, decoded.recording.startedAt)
        XCTAssertEqual(roundTripped.recording.endedAt, decoded.recording.endedAt)
        XCTAssertEqual(roundTripped.recording.duration, decoded.recording.duration)
        XCTAssertEqual(roundTripped.recording.resolution, decoded.recording.resolution)
        XCTAssertEqual(roundTripped.recording.frameRate, decoded.recording.frameRate)
        XCTAssertEqual(roundTripped.recording.codec, decoded.recording.codec)
        XCTAssertEqual(roundTripped.locationTrack.count, decoded.locationTrack.count)
        XCTAssertEqual(roundTripped.locationTrack.first?.ts, decoded.locationTrack.first?.ts)
        XCTAssertEqual(roundTripped.locationTrack.first?.lat, decoded.locationTrack.first?.lat)
        XCTAssertEqual(roundTripped.locationTrack.first?.lng, decoded.locationTrack.first?.lng)
        XCTAssertEqual(roundTripped.locationTrack.first?.speed, decoded.locationTrack.first?.speed)
        XCTAssertEqual(roundTripped.locationTrack.first?.heading, decoded.locationTrack.first?.heading)
        XCTAssertEqual(roundTripped.integrity?.algorithm, decoded.integrity?.algorithm)
        XCTAssertEqual(roundTripped.integrity?.hash, decoded.integrity?.hash)
        XCTAssertEqual(roundTripped.integrity?.signatureAlgorithm, decoded.integrity?.signatureAlgorithm)
        XCTAssertEqual(roundTripped.integrity?.signature, decoded.integrity?.signature)
        XCTAssertEqual(roundTripped.integrity?.publicKey, decoded.integrity?.publicKey)
        XCTAssertEqual(roundTripped.userNote, decoded.userNote)
        XCTAssertEqual(roundTripped.reportedAt, decoded.reportedAt)
    }

    func testMalformedMetadataJSONThrows() {
        XCTAssertThrowsError(
            try JSONDecoder().decode(RecordingMetadata.self, from: Data("{not json".utf8))
        )
    }

    func testUnknownMetadataVersionIsCurrentlyDecodedAndPreserved() throws {
        // Characterization only: RecordingMetadata currently has no version validation.
        guard var object = try JSONSerialization.jsonObject(
            with: Data(contentsOf: fixtureURL())
        ) as? [String: Any] else {
            return XCTFail("Fixture must contain a JSON object")
        }
        object["version"] = "99.0"
        let data = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(RecordingMetadata.self, from: data)

        XCTAssertEqual(decoded.version, "99.0")
    }

    func testLegacySignaturePayloadIsUTF8HashText() {
        let hash = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
        let payload = Data(hash.utf8)

        XCTAssertEqual(payload, Data(hash.utf8))
        XCTAssertEqual(payload.count, 64)
        XCTAssertEqual(String(decoding: payload, as: UTF8.self), hash)
    }

    func testSecurityFrameworkECDSASignsAndVerifiesLegacyPayload() throws {
        let hash = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
        let payload = Data(hash.utf8)
        let privateKey = try makeEphemeralPrivateKey()
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw NSError(domain: "EvidenceCoreCharacterizationTests", code: 1)
        }
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .ecdsaSignatureMessageX962SHA256,
            payload as CFData,
            nil
        ) else {
            throw NSError(domain: "EvidenceCoreCharacterizationTests", code: 2)
        }

        XCTAssertFalse((signature as Data).isEmpty)
        XCTAssertTrue(
            SecKeyVerifySignature(
                publicKey,
                .ecdsaSignatureMessageX962SHA256,
                payload as CFData,
                signature,
                nil
            )
        )
    }

    func testPublicKeyExportAndPEMRemainStableForEphemeralKey() throws {
        let privateKey = try makeEphemeralPrivateKey()
        let firstExport = try publicKeyData(for: privateKey)
        let secondExport = try publicKeyData(for: privateKey)
        let base64 = firstExport.base64EncodedString(
            options: [.lineLength64Characters, .endLineWithLineFeed]
        )
        let pem = "-----BEGIN PUBLIC KEY-----\n\(base64)\n-----END PUBLIC KEY-----"

        XCTAssertEqual(firstExport, secondExport)
        XCTAssertTrue(pem.hasPrefix("-----BEGIN PUBLIC KEY-----\n"))
        XCTAssertTrue(pem.hasSuffix("\n-----END PUBLIC KEY-----"))

        let body = pem
            .replacingOccurrences(of: "-----BEGIN PUBLIC KEY-----\n", with: "")
            .replacingOccurrences(of: "\n-----END PUBLIC KEY-----", with: "")
        XCTAssertEqual(
            Data(base64Encoded: body, options: .ignoreUnknownCharacters),
            firstExport
        )

        // These raw X9.63 bytes are not claimed to be SPKI.
    }

    private func makeEphemeralPrivateKey() throws -> SecKey {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: false
            ]
        ]
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, nil) else {
            throw NSError(domain: "EvidenceCoreCharacterizationTests", code: 3)
        }
        return privateKey
    }

    private func publicKeyData(for privateKey: SecKey) throws -> Data {
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw NSError(domain: "EvidenceCoreCharacterizationTests", code: 4)
        }
        guard let data = SecKeyCopyExternalRepresentation(publicKey, nil) else {
            throw NSError(domain: "EvidenceCoreCharacterizationTests", code: 5)
        }
        return data as Data
    }

    private func fixtureURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/legacy-recording-metadata-v1.json")
    }
}
