import Foundation

struct VideoEvidencePackageManifestV2: Codable, Equatable {
    let schemaVersion: String
    let packageID: UUID
    let requiredTracks: [String]
    let artifacts: [Artifact]

    init(packageID: UUID, requiredTracks: [String], artifacts: [Artifact]) {
        self.schemaVersion = "2.0"
        self.packageID = packageID
        self.requiredTracks = requiredTracks.sorted()
        self.artifacts = artifacts.sorted { $0.name < $1.name }
    }

    struct Artifact: Codable, Equatable {
        let name: String
        let sha256: String
    }

    func canonicalData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }
}

/// Atomic publication boundary for Video Evidence V2.
final class VideoEvidencePackageFinalizerV2 {
    enum Error: Swift.Error, Equatable {
        case packageAlreadyExists
        case stagedVideoIsNotAFile
        case copiedVideoDigestMismatch
    }

    private let signer: any PhotoEvidenceSigningV2
    private let publicKeyProvider: any PhotoEvidencePublicKeyProvidingV2
    private let fileManager: FileManager

    init(
        signer: any PhotoEvidenceSigningV2,
        publicKeyProvider: any PhotoEvidencePublicKeyProvidingV2,
        fileManager: FileManager = .default
    ) {
        self.signer = signer
        self.publicKeyProvider = publicKeyProvider
        self.fileManager = fileManager
    }

    convenience init(signatureService: SignatureService = SignatureService(), fileManager: FileManager = .default) {
        let collaborator = VideoSignatureServiceCollaborator(service: signatureService)
        self.init(signer: collaborator, publicKeyProvider: collaborator, fileManager: fileManager)
    }

    @discardableResult
    func finalize(
        stagedVideoURL: URL,
        claim: VideoEvidenceClaimV2,
        packageDirectory: URL
    ) throws -> URL {
        guard !fileManager.fileExists(atPath: packageDirectory.path) else { throw Error.packageAlreadyExists }
        var sourceIsDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: stagedVideoURL.path, isDirectory: &sourceIsDirectory), !sourceIsDirectory.boolValue else {
            throw Error.stagedVideoIsNotAFile
        }

        let staging = packageDirectory.deletingLastPathComponent()
            .appendingPathComponent(".\(packageDirectory.lastPathComponent).video-staging-\(UUID().uuidString)", isDirectory: true)
        do {
            try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
            defer { try? fileManager.removeItem(at: staging) }

            let original = staging.appendingPathComponent(VideoEvidenceClaimV2.originalFileName)
            try fileManager.moveItem(at: stagedVideoURL, to: original)
            let mediaHash = try HashCalculator.sha256(of: original)
            let byteLength = (try fileManager.attributesOfItem(atPath: original.path)[.size] as? NSNumber)?.intValue ?? 0
            guard try HashCalculator.sha256(of: original) == mediaHash else { throw Error.copiedVideoDigestMismatch }

            let frozenClaim = claim.replacingMediaDigest(mediaHash, byteLength: byteLength)
            let claimData = try frozenClaim.canonicalData()
            let claimURL = staging.appendingPathComponent("claim.json")
            try claimData.write(to: claimURL, options: .atomic)
            let claimHash = HashCalculator.sha256(of: claimData)

            let payload = try EvidenceSigningPayloadV2(packageID: frozenClaim.packageID, mediaSHA256: mediaHash, claimSHA256: claimHash)
            let envelope = EvidenceSignatureEnvelopeV2(
                packageID: frozenClaim.packageID,
                mediaHash: .init(value: mediaHash),
                claimHash: .init(value: claimHash),
                signature: .init(value: try signer.sign(payload.utf8Data).base64EncodedString()),
                publicKey: .init(value: try publicKeyProvider.publicKeyData().base64EncodedString())
            )
            let signatureEncoder = JSONEncoder()
            signatureEncoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            let signatureData = try signatureEncoder.encode(envelope)
            let signatureURL = staging.appendingPathComponent("signature.json")
            try signatureData.write(to: signatureURL, options: .atomic)

            let manifest = VideoEvidencePackageManifestV2(
                packageID: frozenClaim.packageID,
                requiredTracks: frozenClaim.requiredTracks,
                artifacts: [
                    .init(name: VideoEvidenceClaimV2.originalFileName, sha256: mediaHash),
                    .init(name: "claim.json", sha256: claimHash),
                    .init(name: "signature.json", sha256: HashCalculator.sha256(of: signatureData))
                ]
            )
            try manifest.canonicalData().write(to: staging.appendingPathComponent("manifest.json"), options: .atomic)
            try synchronizeFiles(in: staging)

            // The sibling move is the atomic publication point. No partial
            // package is visible at the destination before this call.
            try fileManager.moveItem(at: staging, to: packageDirectory)
            return packageDirectory
        } catch {
            // Idempotent cleanup/quarantine policy: remove only Task-owned
            // staging. A pre-existing destination is never replaced.
            try? fileManager.removeItem(at: staging)
            throw error
        }
    }

    private func synchronizeFiles(in directory: URL) throws {
        for name in try fileManager.contentsOfDirectory(atPath: directory.path) {
            let handle = try FileHandle(forWritingTo: directory.appendingPathComponent(name))
            try handle.synchronize()
            try handle.close()
        }
    }
}

private final class VideoSignatureServiceCollaborator: PhotoEvidenceSigningV2, PhotoEvidencePublicKeyProvidingV2 {
    private let service: SignatureService
    init(service: SignatureService) { self.service = service }
    func sign(_ data: Data) throws -> Data { try service.sign(data: data) }
    func publicKeyData() throws -> Data { try service.publicKeyData() }
}
