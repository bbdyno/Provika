import Foundation
import Security

enum VideoEvidencePackageVerificationResultV2: Equatable {
    case valid
    case missingFile(String)
    case unreadableFile(String)
    case malformedClaim
    case malformedSignature
    case malformedManifest
    case unsupportedVersion(String)
    case unsupportedAlgorithm(String)
    case mediaHashMismatch
    case claimHashMismatch
    case malformedKey
    case invalidSignature
    case manifestMismatch
    case trackPolicyFailure
    case incompletePackage
    case unexpectedArtifact
}

struct VideoEvidenceVerificationPolicyV2: Equatable, Sendable {
    let supportedSchemaVersion: String
    let requiredTracks: Set<String>?

    init(supportedSchemaVersion: String = "2.0", requiredTracks: Set<String>? = nil) {
        self.supportedSchemaVersion = supportedSchemaVersion
        self.requiredTracks = requiredTracks
    }
}

/// Independent offline verifier. It accepts only package bytes and a trust
/// policy; it has no Keychain, SignatureService, network, UI, analytics, or
/// Locale.current dependency. Typed hashMismatch cases remain component-specific.
struct VideoEvidencePackageVerifierV2 {
    private let fileManager: FileManager
    init(fileManager: FileManager = .default) { self.fileManager = fileManager }

    func verify(
        packageDirectory: URL,
        policy: VideoEvidenceVerificationPolicyV2 = .init()
    ) -> VideoEvidencePackageVerificationResultV2 {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: packageDirectory.path, isDirectory: &isDirectory) else {
            return .missingFile(packageDirectory.lastPathComponent)
        }
        guard isDirectory.boolValue else { return .incompletePackage }

        let requiredNames = Set(["original.mov", "claim.json", "signature.json", "manifest.json"])
        let names: Set<String>
        do { names = Set(try fileManager.contentsOfDirectory(atPath: packageDirectory.path)) }
        catch { return .unreadableFile(packageDirectory.lastPathComponent) }
        if let missing = requiredNames.subtracting(names).sorted().first { return .missingFile(missing) }
        guard names == requiredNames else { return .unexpectedArtifact }
        for name in requiredNames where !regularFile(packageDirectory.appendingPathComponent(name)) {
            return .incompletePackage
        }

        let mediaURL = packageDirectory.appendingPathComponent("original.mov")
        let claimURL = packageDirectory.appendingPathComponent("claim.json")
        let signatureURL = packageDirectory.appendingPathComponent("signature.json")
        let manifestURL = packageDirectory.appendingPathComponent("manifest.json")
        let claimData: Data
        let signatureData: Data
        let manifestData: Data
        do {
            claimData = try Data(contentsOf: claimURL)
            signatureData = try Data(contentsOf: signatureURL)
            manifestData = try Data(contentsOf: manifestURL)
        } catch {
            return .unreadableFile("package-artifact")
        }

        guard let claimObject = object(claimData) else { return .malformedClaim }
        guard let signatureObject = object(signatureData) else { return .malformedSignature }
        guard let manifestObject = object(manifestData) else { return .malformedManifest }
        for object in [claimObject, signatureObject, manifestObject] {
            guard let schemaVersion = object["schemaVersion"] as? String else { return .malformedClaim }
            guard schemaVersion == policy.supportedSchemaVersion else { return .unsupportedVersion(schemaVersion) }
        }
        if let audioIncluded = claimObject["audioIncluded"] as? Bool {
            let hasAudioTrack = !(claimObject["audioTrack"] is NSNull) && claimObject["audioTrack"] != nil
            guard audioIncluded == hasAudioTrack else { return .trackPolicyFailure }
        }

        guard nestedString(["mediaHash", "algorithm"], signatureObject) == "sha256",
              nestedString(["claimHash", "algorithm"], signatureObject) == "sha256" else {
            return .unsupportedAlgorithm("hash")
        }
        guard nestedString(["signature", "algorithm"], signatureObject) == "ecdsa-p256-sha256-x962",
              nestedString(["signature", "payloadFormat"], signatureObject) == "provika-evidence-signature-v2" else {
            return .unsupportedAlgorithm("signature")
        }
        guard nestedString(["publicKey", "format"], signatureObject) == "p256-x963" else {
            return .unsupportedAlgorithm("publicKey")
        }

        let claim: VideoEvidenceClaimV2
        let envelope: EvidenceSignatureEnvelopeV2
        let manifest: VideoEvidencePackageManifestV2
        do { claim = try JSONDecoder().decode(VideoEvidenceClaimV2.self, from: claimData) }
        catch { return .malformedClaim }
        guard (try? claim.canonicalData()) == claimData else { return .malformedClaim }
        do { envelope = try JSONDecoder().decode(EvidenceSignatureEnvelopeV2.self, from: signatureData) }
        catch { return .malformedSignature }
        do { manifest = try JSONDecoder().decode(VideoEvidencePackageManifestV2.self, from: manifestData) }
        catch { return .malformedManifest }

        let mediaHash: String
        do { mediaHash = try HashCalculator.sha256(of: mediaURL) }
        catch { return .unreadableFile("original.mov") }
        let claimHash = HashCalculator.sha256(of: claimData)
        guard claim.media.sha256 == mediaHash, envelope.mediaHash.value == mediaHash else { return .mediaHashMismatch }
        guard envelope.claimHash.value == claimHash else { return .claimHashMismatch }
        guard claim.packageID == envelope.packageID, claim.packageID == manifest.packageID else { return .manifestMismatch }

        let observedTracks = Set(claim.requiredTracks)
        guard Set(manifest.requiredTracks) == observedTracks else { return .trackPolicyFailure }
        if let requiredTracks = policy.requiredTracks, !requiredTracks.isSubset(of: observedTracks) {
            return .trackPolicyFailure
        }

        guard let signature = Data(base64Encoded: envelope.signature.value) else { return .malformedSignature }
        guard let publicKeyBytes = Data(base64Encoded: envelope.publicKey.value),
              let publicKey = importP256PublicKey(publicKeyBytes) else { return .malformedKey }
        let payload: EvidenceSigningPayloadV2
        do { payload = try .init(packageID: claim.packageID, mediaSHA256: mediaHash, claimSHA256: claimHash) }
        catch { return .malformedSignature }
        guard SecKeyVerifySignature(publicKey, .ecdsaSignatureMessageX962SHA256, payload.utf8Data as CFData, signature as CFData, nil) else {
            return .invalidSignature
        }

        let expectedManifest: [String: String] = [
            "original.mov": mediaHash,
            "claim.json": claimHash,
            "signature.json": HashCalculator.sha256(of: signatureData)
        ]
        guard Set(manifest.artifacts.map(\.name)).count == manifest.artifacts.count else { return .manifestMismatch }
        let manifestArtifacts = Dictionary(uniqueKeysWithValues: manifest.artifacts.map { ($0.name, $0.sha256) })
        guard manifestArtifacts == expectedManifest else { return .manifestMismatch }
        return .valid
    }

    private func regularFile(_ url: URL) -> Bool {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path) else { return false }
        return attributes[.type] as? FileAttributeType == .typeRegular
    }
    private func object(_ data: Data) -> [String: Any]? {
        try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
    private func nestedString(_ path: [String], _ object: [String: Any]) -> String? {
        var current: Any = object
        for component in path {
            guard let dictionary = current as? [String: Any], let next = dictionary[component] else { return nil }
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
