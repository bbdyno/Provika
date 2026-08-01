import Foundation
import Security
import XCTest
@testable import Provika

final class EvidenceSignatureVerifierTests: XCTestCase {
    private let legacyHash = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

    func testVerifiesLegacySignatureWithEphemeralPublicKey() throws {
        let privateKey = try makeEphemeralPrivateKey()
        let publicKeyPEM = try legacyPEM(for: privateKey)
        let signature = try sign(hash: legacyHash, with: privateKey)

        XCTAssertTrue(
            try EvidenceSignatureVerifier().verify(
                signature: signature,
                hash: legacyHash,
                publicKeyPEM: publicKeyPEM
            )
        )
    }

    func testRejectsModifiedLegacyPayload() throws {
        let privateKey = try makeEphemeralPrivateKey()
        let signature = try sign(hash: legacyHash, with: privateKey)

        XCTAssertFalse(
            try EvidenceSignatureVerifier().verify(
                signature: signature,
                hash: legacyHash + "0",
                publicKeyPEM: try legacyPEM(for: privateKey)
            )
        )
    }

    func testRejectsSignatureFromDifferentKey() throws {
        let signingKey = try makeEphemeralPrivateKey()
        let differentKey = try makeEphemeralPrivateKey()
        let signature = try sign(hash: legacyHash, with: signingKey)

        XCTAssertFalse(
            try EvidenceSignatureVerifier().verify(
                signature: signature,
                hash: legacyHash,
                publicKeyPEM: try legacyPEM(for: differentKey)
            )
        )
    }

    func testAcceptsMultilineLegacyPEM() throws {
        let privateKey = try makeEphemeralPrivateKey()
        let publicKey = try publicKeyData(for: privateKey).base64EncodedString()
        let lines = stride(from: 0, to: publicKey.count, by: 11).map {
            let start = publicKey.index(publicKey.startIndex, offsetBy: $0)
            let end = publicKey.index(start, offsetBy: min(11, publicKey.distance(from: start, to: publicKey.endIndex)))
            return String(publicKey[start..<end])
        }
        let pem = "-----BEGIN PUBLIC KEY-----\n\(lines.joined(separator: " \n\t"))\n-----END PUBLIC KEY-----"

        XCTAssertTrue(
            try EvidenceSignatureVerifier().verify(
                signature: try sign(hash: legacyHash, with: privateKey),
                hash: legacyHash,
                publicKeyPEM: pem
            )
        )
    }

    func testRejectsMalformedAndNonImportableLegacyPEM() throws {
        let verifier = EvidenceSignatureVerifier()

        XCTAssertThrowsError(
            try verifier.verify(signature: Data(), hash: legacyHash, publicKeyPEM: "")
        ) { XCTAssertEqual($0 as? EvidenceSignatureVerifier.Error, .emptyPublicKey) }
        XCTAssertThrowsError(
            try verifier.verify(
                signature: Data(),
                hash: legacyHash,
                publicKeyPEM: "-----BEGIN EC PUBLIC KEY-----\nAAAA\n-----END EC PUBLIC KEY-----"
            )
        ) { XCTAssertEqual($0 as? EvidenceSignatureVerifier.Error, .malformedPublicKeyEnvelope) }
        XCTAssertThrowsError(
            try verifier.verify(
                signature: Data(),
                hash: legacyHash,
                publicKeyPEM: "-----BEGIN PUBLIC KEY-----\nnot base64!\n-----END PUBLIC KEY-----"
            )
        ) { XCTAssertEqual($0 as? EvidenceSignatureVerifier.Error, .malformedPublicKeyBase64) }
        XCTAssertThrowsError(
            try verifier.verify(
                signature: Data(),
                hash: legacyHash,
                publicKeyPEM: "-----BEGIN PUBLIC KEY-----\nAAAA\n-----END PUBLIC KEY-----"
            )
        ) { XCTAssertEqual($0 as? EvidenceSignatureVerifier.Error, .publicKeyImportFailed) }
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
            throw NSError(domain: "EvidenceSignatureVerifierTests", code: 1)
        }
        return privateKey
    }

    private func publicKeyData(for privateKey: SecKey) throws -> Data {
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw NSError(domain: "EvidenceSignatureVerifierTests", code: 2)
        }
        guard let data = SecKeyCopyExternalRepresentation(publicKey, nil) else {
            throw NSError(domain: "EvidenceSignatureVerifierTests", code: 3)
        }
        return data as Data
    }

    private func legacyPEM(for privateKey: SecKey) throws -> String {
        let base64 = try publicKeyData(for: privateKey).base64EncodedString()
        return "-----BEGIN PUBLIC KEY-----\n\(base64)\n-----END PUBLIC KEY-----"
    }

    private func sign(hash: String, with privateKey: SecKey) throws -> Data {
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .ecdsaSignatureMessageX962SHA256,
            Data(hash.utf8) as CFData,
            nil
        ) else {
            throw NSError(domain: "EvidenceSignatureVerifierTests", code: 4)
        }
        return signature as Data
    }
}
