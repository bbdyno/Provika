import Foundation

protocol PhotoEvidenceSigningV2 {
    func sign(_ data: Data) throws -> Data
}

protocol PhotoEvidencePublicKeyProvidingV2 {
    func publicKeyData() throws -> Data
}

/// Writes a V2 evidence package as an all-or-nothing directory publication.
final class PhotoEvidencePackageFinalizerV2 {
    enum Error: Swift.Error, Equatable {
        case packageAlreadyExists
        case originalPhotoIsNotAFile
        case copiedPhotoDigestMismatch
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
        let collaborator = SignatureServiceCollaborator(service: signatureService)
        self.init(signer: collaborator, publicKeyProvider: collaborator, fileManager: fileManager)
    }

    /// Finalizes `packageDirectory` only after every artifact has been generated in a private sibling directory.
    @discardableResult
    func finalize(
        originalPhotoURL: URL,
        claim: PhotoEvidenceClaimV2,
        packageDirectory: URL
    ) throws -> URL {
        guard !fileManager.fileExists(atPath: packageDirectory.path) else {
            throw Error.packageAlreadyExists
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: originalPhotoURL.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            throw Error.originalPhotoIsNotAFile
        }

        let stagingDirectory = packageDirectory
            .deletingLastPathComponent()
            .appendingPathComponent(".\(packageDirectory.lastPathComponent).staging-\(UUID().uuidString)", isDirectory: true)

        do {
            try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
            defer { try? fileManager.removeItem(at: stagingDirectory) }

            let originalDigest = try HashCalculator.sha256(of: originalPhotoURL)
            let frozenClaim = try EvidenceCoreCanonicalizationV2.frozenClaim(
                replacingMediaDigest: originalDigest,
                in: claim
            )
            let photoURL = stagingDirectory.appendingPathComponent(frozenClaim.media.fileName)
            try fileManager.copyItem(at: originalPhotoURL, to: photoURL)

            guard try HashCalculator.sha256(of: photoURL) == originalDigest else {
                throw Error.copiedPhotoDigestMismatch
            }

            let claimData = try EvidenceCoreCanonicalizationV2.canonicalClaimData(for: frozenClaim)
            let claimURL = stagingDirectory.appendingPathComponent("claim.json")
            try claimData.write(to: claimURL, options: .atomic)
            let claimDigest = try HashCalculator.sha256(of: claimURL)

            let signingPayload = try EvidenceSigningPayloadV2(
                packageID: frozenClaim.packageID,
                mediaSHA256: originalDigest,
                claimSHA256: claimDigest
            )
            let signature = try signer.sign(signingPayload.utf8Data)
            let publicKey = try publicKeyProvider.publicKeyData()
            let envelope = EvidenceSignatureEnvelopeV2(
                packageID: frozenClaim.packageID,
                mediaHash: .init(value: originalDigest),
                claimHash: .init(value: claimDigest),
                signature: .init(value: signature.base64EncodedString()),
                publicKey: .init(value: publicKey.base64EncodedString())
            )
            // The envelope remains on its established serialization path. Only
            // the claim crosses the locale-neutral Core boundary above.
            try JSONEncoder().encode(envelope).write(
                to: stagingDirectory.appendingPathComponent("signature.json"),
                options: .atomic
            )

            try fileManager.moveItem(at: stagingDirectory, to: packageDirectory)
            return packageDirectory
        } catch {
            try? fileManager.removeItem(at: stagingDirectory)
            throw error
        }
    }

}

private final class SignatureServiceCollaborator: PhotoEvidenceSigningV2, PhotoEvidencePublicKeyProvidingV2 {
    private let service: SignatureService

    init(service: SignatureService) {
        self.service = service
    }

    func sign(_ data: Data) throws -> Data {
        try service.sign(data: data)
    }

    func publicKeyData() throws -> Data {
        try service.publicKeyData()
    }
}
