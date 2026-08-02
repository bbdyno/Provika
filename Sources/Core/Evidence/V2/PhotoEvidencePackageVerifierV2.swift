import Foundation
import Security

/// The bounded outcome of an offline inspection of a frozen V2 photo package.
enum PhotoEvidencePackageVerificationResultV2: Equatable {
    case valid
    case missingRequiredArtifact
    case unreadableArtifact
    case malformedClaim
    case unsupportedSchemaVersion
    case unsupportedSignatureAlgorithm
    case malformedSignatureEnvelope
    case malformedPublicKey
    case originalMediaDigestMismatch
    case claimDigestMismatch
    case invalidSignature
    case unexpectedArtifactType
    case ioFailure
}

/// Verifies the three-artifact V2 package without changing any package bytes.
struct PhotoEvidencePackageVerifierV2 {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func verify(packageDirectory: URL) -> PhotoEvidencePackageVerificationResultV2 {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: packageDirectory.path, isDirectory: &isDirectory) else {
            return .ioFailure
        }
        guard isDirectory.boolValue else {
            return .unexpectedArtifactType
        }

        let names: [String]
        do {
            names = try fileManager.contentsOfDirectory(atPath: packageDirectory.path)
        } catch {
            return .ioFailure
        }

        guard names.contains("claim.json"), names.contains("signature.json") else {
            return .missingRequiredArtifact
        }
        guard artifactIsRegularFile(named: "claim.json", in: packageDirectory),
              artifactIsRegularFile(named: "signature.json", in: packageDirectory) else {
            return .unexpectedArtifactType
        }

        let claimURL = packageDirectory.appendingPathComponent("claim.json", isDirectory: false)
        let signatureURL = packageDirectory.appendingPathComponent("signature.json", isDirectory: false)
        let claimData: Data
        let signatureData: Data
        do {
            claimData = try Data(contentsOf: claimURL)
            signatureData = try Data(contentsOf: signatureURL)
        } catch {
            return .unreadableArtifact
        }

        guard let claimObject = jsonObject(from: claimData) else { return .malformedClaim }
        guard let claimSchemaVersion = stringValue("schemaVersion", in: claimObject) else { return .malformedClaim }
        guard claimSchemaVersion == "2.0" else { return .unsupportedSchemaVersion }
        let claim: PhotoEvidenceClaimV2
        do {
            claim = try JSONDecoder().decode(PhotoEvidenceClaimV2.self, from: claimData)
        } catch {
            return .malformedClaim
        }

        guard isSafeFileName(claim.media.fileName),
              claim.media.fileName != "claim.json",
              claim.media.fileName != "signature.json" else { return .unexpectedArtifactType }
        let mediaURL = packageDirectory.appendingPathComponent(claim.media.fileName, isDirectory: false)
        guard names.contains(claim.media.fileName) else { return .missingRequiredArtifact }
        guard artifactIsRegularFile(named: claim.media.fileName, in: packageDirectory) else {
            return .unexpectedArtifactType
        }
        let expectedNames: Set<String> = ["claim.json", "signature.json", claim.media.fileName]
        guard Set(names) == expectedNames else { return .unexpectedArtifactType }

        guard let envelopeObject = jsonObject(from: signatureData) else { return .malformedSignatureEnvelope }
        guard let envelopeSchemaVersion = stringValue("schemaVersion", in: envelopeObject) else { return .malformedSignatureEnvelope }
        guard envelopeSchemaVersion == "2.0" else { return .unsupportedSchemaVersion }
        guard let signatureAlgorithm = nestedStringValue(["signature", "algorithm"], in: envelopeObject) else { return .malformedSignatureEnvelope }
        guard signatureAlgorithm == "ecdsa-p256-sha256-x962" else { return .unsupportedSignatureAlgorithm }
        let envelope: EvidenceSignatureEnvelopeV2
        do {
            envelope = try JSONDecoder().decode(EvidenceSignatureEnvelopeV2.self, from: signatureData)
        } catch {
            return .malformedSignatureEnvelope
        }

        let mediaDigest: String
        do {
            mediaDigest = try HashCalculator.sha256(of: mediaURL)
        } catch {
            return .unreadableArtifact
        }
        let claimDigest = HashCalculator.sha256(of: claimData)
        guard claim.media.sha256 == mediaDigest, envelope.mediaHash.value == mediaDigest else {
            return .originalMediaDigestMismatch
        }
        guard envelope.claimHash.value == claimDigest else { return .claimDigestMismatch }
        guard envelope.packageID == claim.packageID else { return .invalidSignature }

        guard let signature = Data(base64Encoded: envelope.signature.value) else {
            return .malformedSignatureEnvelope
        }
        guard let publicKeyData = Data(base64Encoded: envelope.publicKey.value) else {
            return .malformedPublicKey
        }
        guard let publicKey = importP256PublicKey(publicKeyData) else {
            return .malformedPublicKey
        }
        let payload: EvidenceSigningPayloadV2
        do {
            payload = try EvidenceSigningPayloadV2(
                packageID: claim.packageID,
                mediaSHA256: mediaDigest,
                claimSHA256: claimDigest
            )
        } catch {
            return .malformedSignatureEnvelope
        }
        return SecKeyVerifySignature(
            publicKey,
            .ecdsaSignatureMessageX962SHA256,
            payload.utf8Data as CFData,
            signature as CFData,
            nil
        ) ? .valid : .invalidSignature
    }

    private func artifactIsRegularFile(named name: String, in directory: URL) -> Bool {
        let url = directory.appendingPathComponent(name, isDirectory: false)
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path) else { return false }
        return attributes[.type] as? FileAttributeType == .typeRegular
    }

    private func isSafeFileName(_ value: String) -> Bool {
        !value.isEmpty && value != "." && value != ".." &&
            !value.contains("/") && !value.contains("\\") &&
            URL(fileURLWithPath: value).lastPathComponent == value
    }

    private func jsonObject(from data: Data) -> [String: Any]? {
        try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private func stringValue(_ key: String, in object: [String: Any]) -> String? {
        object[key] as? String
    }

    private func nestedStringValue(_ path: [String], in object: [String: Any]) -> String? {
        var current: Any = object
        for key in path {
            guard let dictionary = current as? [String: Any], let next = dictionary[key] else { return nil }
            current = next
        }
        return current as? String
    }

    private func importP256PublicKey(_ data: Data) -> SecKey? {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits as String: 256
        ]
        return SecKeyCreateWithData(data as CFData, attributes as CFDictionary, nil)
    }
}
