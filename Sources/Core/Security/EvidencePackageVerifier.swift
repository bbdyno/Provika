//
//  EvidencePackageVerifier.swift
//  Provika
//

import Foundation

/// Synchronously verifies an existing media file and its legacy JSON sidecar.
///
/// This verifier is intentionally offline and read-only: it neither accesses
/// the Keychain nor changes either package file.
struct EvidencePackageVerifier {
    enum Outcome: Equatable {
        case verified
        case missingMedia
        case missingMetadata
        case unreadableMedia
        case unreadableMetadata
        case malformedMetadata
        case unsupportedMetadataVersion(String)
        case missingIntegrity
        case unsupportedHashAlgorithm(String)
        case hashMismatch(expected: String, actual: String)
        case missingSignatureFields
        case partialSignatureFields
        case unsupportedSignatureAlgorithm(String)
        case malformedSignatureBase64
        case invalidEmbeddedPublicKey
        case invalidSignature
    }

    private let fileManager: FileManager
    private let metadataReader: EvidenceMetadataReader
    private let signatureVerifier: EvidenceSignatureVerifier

    init(
        fileManager: FileManager = .default,
        metadataReader: EvidenceMetadataReader = EvidenceMetadataReader(),
        signatureVerifier: EvidenceSignatureVerifier = EvidenceSignatureVerifier()
    ) {
        self.fileManager = fileManager
        self.metadataReader = metadataReader
        self.signatureVerifier = signatureVerifier
    }

    func verify(mediaURL: URL, metadataURL: URL) -> Outcome {
        switch fileState(at: mediaURL) {
        case .missing:
            return .missingMedia
        case .unreadable:
            return .unreadableMedia
        case .readable:
            break
        }

        let metadata: RecordingMetadata
        switch metadataReader.read(from: metadataURL) {
        case let .loaded(loadedMetadata):
            metadata = loadedMetadata
        case .missingFile:
            return .missingMetadata
        case .unreadableFile:
            return .unreadableMetadata
        case .malformedMetadata:
            return .malformedMetadata
        case let .unsupportedVersion(version):
            return .unsupportedMetadataVersion(version)
        }

        guard let integrity = metadata.integrity,
              !integrity.algorithm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !integrity.hash.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .missingIntegrity
        }
        guard integrity.algorithm == "SHA-256" else {
            return .unsupportedHashAlgorithm(integrity.algorithm)
        }

        let actualHash: String
        do {
            actualHash = try HashCalculator.sha256(of: mediaURL)
        } catch {
            return .unreadableMedia
        }
        guard integrity.hash == actualHash else {
            return .hashMismatch(expected: integrity.hash, actual: actualHash)
        }

        let signatureFields = [
            integrity.signatureAlgorithm,
            integrity.signature,
            integrity.publicKey
        ]
        if signatureFields.allSatisfy({ $0 == nil }) {
            return .missingSignatureFields
        }
        guard let signatureAlgorithm = integrity.signatureAlgorithm,
              let signatureText = integrity.signature,
              let publicKey = integrity.publicKey,
              !signatureAlgorithm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !signatureText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !publicKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .partialSignatureFields
        }
        guard signatureAlgorithm == "ECDSA-P256-SHA256" else {
            return .unsupportedSignatureAlgorithm(signatureAlgorithm)
        }
        guard let signature = Data(base64Encoded: signatureText, options: []) else {
            return .malformedSignatureBase64
        }

        do {
            guard try signatureVerifier.verify(
                signature: signature,
                hash: integrity.hash,
                publicKeyPEM: publicKey
            ) else {
                return .invalidSignature
            }
        } catch {
            return .invalidEmbeddedPublicKey
        }
        return .verified
    }
}

private extension EvidencePackageVerifier {
    enum FileState {
        case missing
        case unreadable
        case readable
    }

    func fileState(at url: URL) -> FileState {
        var isDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return .missing
        }
        return isDirectory.boolValue ? .unreadable : .readable
    }
}
