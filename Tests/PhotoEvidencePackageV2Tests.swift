import Foundation
import XCTest
@testable import Provika

final class PhotoEvidencePackageV2Tests: XCTestCase {
    private let validHash = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
    private let packageID = UUID(uuidString: "A0B1C2D3-E4F5-4678-9ABC-DEF012345678")!

    func testSyntheticClaimFixtureDecodesExactImportantValues() throws {
        let claim = try decodeFixture()

        XCTAssertEqual(claim.schemaVersion, "2.0")
        XCTAssertEqual(claim.packageID, packageID)
        XCTAssertEqual(claim.media.fileName, "synthetic-photo.jpg")
        XCTAssertEqual(claim.media.mediaType, "image/jpeg")
        XCTAssertEqual(claim.media.pixelWidth, 4032)
        XCTAssertEqual(claim.media.pixelHeight, 3024)
        XCTAssertEqual(claim.media.sha256, validHash)
        XCTAssertEqual(claim.capture.deviceTime, "2026-01-02T03:04:05.678Z")
        XCTAssertEqual(claim.capture.timeSource, "device-clock")
        XCTAssertEqual(claim.app.name, "Provika")
        XCTAssertEqual(claim.app.version, "2.0.0")
        XCTAssertEqual(claim.app.build, "200")
        XCTAssertEqual(claim.device.model, "Synthetic iPhone")
        XCTAssertEqual(claim.device.systemVersion, "iOS 18.0")

        let location = try XCTUnwrap(claim.location)
        XCTAssertEqual(location.lat, 37.5665)
        XCTAssertEqual(location.lng, 126.978)
        XCTAssertEqual(location.horizontalAccuracyMeters, 4.5)
        XCTAssertEqual(location.altitudeMeters, 38.2)
        XCTAssertEqual(location.verticalAccuracyMeters, 6.7)
        XCTAssertEqual(location.headingDegrees, 91.25)
        XCTAssertEqual(location.speedMetersPerSecond, 12.3)
        XCTAssertEqual(location.source, "core-location-device")

        let context = try XCTUnwrap(claim.context)
        XCTAssertEqual(context.projectID, "synthetic-project-001")
        XCTAssertEqual(context.projectName, "Synthetic Project")
        XCTAssertEqual(context.note, "Synthetic photo evidence")
        XCTAssertEqual(context.organizationName, "Synthetic Organization")
    }

    func testClaimAndEnvelopeRoundTrip() throws {
        let claim = try decodeFixture()
        let roundTrippedClaim = try JSONDecoder().decode(
            PhotoEvidenceClaimV2.self,
            from: JSONEncoder().encode(claim)
        )
        XCTAssertEqual(roundTrippedClaim, claim)

        let envelope = EvidenceSignatureEnvelopeV2(
            packageID: packageID,
            mediaHash: .init(value: validHash),
            claimHash: .init(value: String(repeating: "a", count: 64)),
            signature: .init(value: "AQIDBA=="),
            publicKey: .init(value: "BQYHCA==")
        )
        let roundTrippedEnvelope = try JSONDecoder().decode(
            EvidenceSignatureEnvelopeV2.self,
            from: JSONEncoder().encode(envelope)
        )
        XCTAssertEqual(roundTrippedEnvelope, envelope)
    }

    func testInitializersUseFixedConstants() {
        let claim = PhotoEvidenceClaimV2(
            packageID: packageID,
            media: .init(fileName: "photo.jpg", mediaType: "image/jpeg", pixelWidth: 1, pixelHeight: 1, sha256: validHash),
            capture: .init(deviceTime: "2026-01-02T03:04:05Z"),
            app: .init(name: "Provika", version: "2.0.0", build: "200"),
            device: .init(model: "Synthetic iPhone", systemVersion: "iOS 18.0"),
            location: .init(lat: 1, lng: 2, horizontalAccuracyMeters: 3)
        )
        let envelope = EvidenceSignatureEnvelopeV2(
            packageID: packageID,
            mediaHash: .init(value: validHash),
            claimHash: .init(value: validHash),
            signature: .init(value: "signature"),
            publicKey: .init(value: "public-key")
        )

        XCTAssertEqual(claim.schemaVersion, "2.0")
        XCTAssertEqual(claim.capture.timeSource, "device-clock")
        XCTAssertEqual(claim.location?.source, "core-location-device")
        XCTAssertEqual(envelope.schemaVersion, "2.0")
        XCTAssertEqual(envelope.mediaHash.algorithm, "sha256")
        XCTAssertEqual(envelope.signature.algorithm, "ecdsa-p256-sha256-x962")
        XCTAssertEqual(envelope.signature.payloadFormat, "provika-evidence-signature-v2")
        XCTAssertEqual(envelope.publicKey.format, "p256-x963")
    }

    func testDecodingRejectsEveryFixedConstantMutation() throws {
        let claimData = try fixtureData()
        try assertClaimMutationRejected(claimData, path: [], key: "schemaVersion", value: "3.0")
        try assertClaimMutationRejected(claimData, path: ["capture"], key: "timeSource", value: "network-time")
        try assertClaimMutationRejected(claimData, path: ["location"], key: "source", value: "external-gps")

        let envelopeData = try JSONEncoder().encode(EvidenceSignatureEnvelopeV2(
            packageID: packageID,
            mediaHash: .init(value: validHash),
            claimHash: .init(value: validHash),
            signature: .init(value: "signature"),
            publicKey: .init(value: "public-key")
        ))
        try assertEnvelopeMutationRejected(envelopeData, path: [], key: "schemaVersion", value: "3.0")
        try assertEnvelopeMutationRejected(envelopeData, path: ["mediaHash"], key: "algorithm", value: "sha512")
        try assertEnvelopeMutationRejected(envelopeData, path: ["signature"], key: "algorithm", value: "rsa")
        try assertEnvelopeMutationRejected(envelopeData, path: ["signature"], key: "payloadFormat", value: "other-format")
        try assertEnvelopeMutationRejected(envelopeData, path: ["publicKey"], key: "format", value: "spki")
    }

    func testMissingOptionalLocationMeasurementsDecodeAsNilIndependently() throws {
        for key in ["altitudeMeters", "verticalAccuracyMeters", "headingDegrees", "speedMetersPerSecond"] {
            let claim = try decodeClaim(removing: key, from: "location")
            let location = try XCTUnwrap(claim.location)
            switch key {
            case "altitudeMeters": XCTAssertNil(location.altitudeMeters)
            case "verticalAccuracyMeters": XCTAssertNil(location.verticalAccuracyMeters)
            case "headingDegrees": XCTAssertNil(location.headingDegrees)
            case "speedMetersPerSecond": XCTAssertNil(location.speedMetersPerSecond)
            default: XCTFail("Unexpected location key: \(key)")
            }
        }
    }

    func testMissingOptionalContextValuesDecodeAsNilIndependently() throws {
        for key in ["projectID", "projectName", "note", "organizationName"] {
            let claim = try decodeClaim(removing: key, from: "context")
            let context = try XCTUnwrap(claim.context)
            switch key {
            case "projectID": XCTAssertNil(context.projectID)
            case "projectName": XCTAssertNil(context.projectName)
            case "note": XCTAssertNil(context.note)
            case "organizationName": XCTAssertNil(context.organizationName)
            default: XCTFail("Unexpected context key: \(key)")
            }
        }
    }

    func testSigningPayloadHasExactCanonicalTextAndUTF8Data() throws {
        let claimHash = String(repeating: "a", count: 64)
        let payload = try EvidenceSigningPayloadV2(
            packageID: packageID,
            mediaSHA256: validHash,
            claimSHA256: claimHash
        )
        let expected = "Provika-Evidence-Package-Signature-V2\npackage-id:a0b1c2d3-e4f5-4678-9abc-def012345678\nmedia-sha256:\(validHash)\nclaim-sha256:\(claimHash)\n"

        XCTAssertEqual(payload.string, expected)
        XCTAssertEqual(payload.string.split(separator: "\n", omittingEmptySubsequences: false).count, 5)
        XCTAssertEqual(payload.utf8Data, Data(expected.utf8))
        XCTAssertEqual(payload.utf8Data, Data(payload.string.utf8))
        XCTAssertTrue(payload.string.hasSuffix("\n"))
        XCTAssertFalse(payload.string.hasSuffix("\n\n"))
    }

    func testSigningPayloadRejectsUppercaseWrongLengthAndNonHexForBothHashes() {
        let uppercase = String(repeating: "a", count: 63) + "A"
        let wrongLength = String(repeating: "a", count: 63)
        let nonHex = String(repeating: "a", count: 63) + "g"

        assertPayloadError(.mediaSHA256ContainsUppercase, mediaHash: uppercase, claimHash: validHash)
        assertPayloadError(.mediaSHA256WrongLength, mediaHash: wrongLength, claimHash: validHash)
        assertPayloadError(.mediaSHA256ContainsNonHex, mediaHash: nonHex, claimHash: validHash)
        assertPayloadError(.claimSHA256ContainsUppercase, mediaHash: validHash, claimHash: uppercase)
        assertPayloadError(.claimSHA256WrongLength, mediaHash: validHash, claimHash: wrongLength)
        assertPayloadError(.claimSHA256ContainsNonHex, mediaHash: validHash, claimHash: nonHex)
    }

    private func decodeFixture() throws -> PhotoEvidenceClaimV2 {
        try JSONDecoder().decode(PhotoEvidenceClaimV2.self, from: fixtureData())
    }

    private func fixtureData() throws -> Data {
        try Data(contentsOf: URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/photo-evidence-claim-v2.json"))
    }

    private func decodeClaim(removing key: String, from section: String) throws -> PhotoEvidenceClaimV2 {
        var object = try fixtureObject()
        var nested = try XCTUnwrap(object[section] as? [String: Any])
        nested.removeValue(forKey: key)
        object[section] = nested
        return try JSONDecoder().decode(PhotoEvidenceClaimV2.self, from: JSONSerialization.data(withJSONObject: object))
    }

    private func assertClaimMutationRejected(_ data: Data, path: [String], key: String, value: String) throws {
        let mutated = try mutating(data, path: path, key: key, value: value)
        XCTAssertThrowsError(try JSONDecoder().decode(PhotoEvidenceClaimV2.self, from: mutated))
    }

    private func assertEnvelopeMutationRejected(_ data: Data, path: [String], key: String, value: String) throws {
        let mutated = try mutating(data, path: path, key: key, value: value)
        XCTAssertThrowsError(try JSONDecoder().decode(EvidenceSignatureEnvelopeV2.self, from: mutated))
    }

    private func mutating(_ data: Data, path: [String], key: String, value: String) throws -> Data {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        if let section = path.first {
            var nested = try XCTUnwrap(object[section] as? [String: Any])
            nested[key] = value
            object[section] = nested
        } else {
            object[key] = value
        }
        return try JSONSerialization.data(withJSONObject: object)
    }

    private func fixtureObject() throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: fixtureData()) as? [String: Any])
    }

    private func assertPayloadError(
        _ expected: EvidenceSigningPayloadV2.Error,
        mediaHash: String,
        claimHash: String
    ) {
        XCTAssertThrowsError(
            try EvidenceSigningPayloadV2(packageID: packageID, mediaSHA256: mediaHash, claimSHA256: claimHash)
        ) {
            XCTAssertEqual($0 as? EvidenceSigningPayloadV2.Error, expected)
        }
    }
}
