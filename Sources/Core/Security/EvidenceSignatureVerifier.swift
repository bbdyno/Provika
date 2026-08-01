//
//  EvidenceSignatureVerifier.swift
//  Provika
//

import Foundation
import Security

/// Verifies the legacy evidence signature sidecar format.
///
/// Legacy `PUBLIC KEY` sidecars contain Security.framework's raw P-256 public
/// key representation wrapped in PEM-like markers. They are not SPKI data.
struct EvidenceSignatureVerifier {
    enum Error: Swift.Error, Equatable {
        case emptyPublicKey
        case malformedPublicKeyEnvelope
        case malformedPublicKeyBase64
        case publicKeyImportFailed
    }

    /// Verifies a legacy ECDSA P-256 X9.62/SHA-256 signature over the exact
    /// UTF-8 bytes of the stored hash text.
    func verify(signature: Data, hash: String, publicKeyPEM: String) throws -> Bool {
        let publicKey = try importLegacyPublicKey(from: publicKeyPEM)

        return SecKeyVerifySignature(
            publicKey,
            .ecdsaSignatureMessageX962SHA256,
            Data(hash.utf8) as CFData,
            signature as CFData,
            nil
        )
    }

    private func importLegacyPublicKey(from pem: String) throws -> SecKey {
        let keyData = try legacyPublicKeyData(from: pem)
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits as String: 256
        ]

        guard let publicKey = SecKeyCreateWithData(keyData as CFData, attributes as CFDictionary, nil) else {
            throw Error.publicKeyImportFailed
        }
        return publicKey
    }

    private func legacyPublicKeyData(from pem: String) throws -> Data {
        guard !pem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Error.emptyPublicKey
        }

        let header = "-----BEGIN PUBLIC KEY-----"
        let footer = "-----END PUBLIC KEY-----"
        guard pem.hasPrefix(header), pem.hasSuffix(footer) else {
            throw Error.malformedPublicKeyEnvelope
        }

        let bodyStart = pem.index(pem.startIndex, offsetBy: header.count)
        let bodyEnd = pem.index(pem.endIndex, offsetBy: -footer.count)
        let body = pem[bodyStart..<bodyEnd]
        guard !body.isEmpty, body.unicodeScalars.contains(where: { $0.properties.isWhitespace }) else {
            throw Error.emptyPublicKey
        }

        let base64 = String(body.unicodeScalars.filter { !$0.properties.isWhitespace })
        guard !base64.isEmpty else {
            throw Error.emptyPublicKey
        }
        guard base64.unicodeScalars.allSatisfy(isBase64Scalar),
              let keyData = Data(base64Encoded: base64) else {
            throw Error.malformedPublicKeyBase64
        }
        return keyData
    }

    private func isBase64Scalar(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 43, 47, 48...57, 61, 65...90, 97...122: // + / 0-9 = A-Z a-z
            return true
        default:
            return false
        }
    }
}
