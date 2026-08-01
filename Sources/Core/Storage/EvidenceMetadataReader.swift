//
//  EvidenceMetadataReader.swift
//  Provika
//

import Foundation

struct EvidenceMetadataReader {
    enum Outcome {
        case loaded(RecordingMetadata)
        case missingFile
        case unreadableFile
        case malformedMetadata
        case unsupportedVersion(String)
    }

    private static let supportedVersion = "1.0"
    private let fileManager: FileManager
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default, decoder: JSONDecoder = JSONDecoder()) {
        self.fileManager = fileManager
        self.decoder = decoder
    }

    func read(from url: URL) -> Outcome {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return .missingFile
        }
        guard !isDirectory.boolValue else {
            return .unreadableFile
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            return .unreadableFile
        }

        let envelope: VersionEnvelope
        do {
            envelope = try decoder.decode(VersionEnvelope.self, from: data)
        } catch {
            return .malformedMetadata
        }

        guard !envelope.version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .malformedMetadata
        }
        guard envelope.version == Self.supportedVersion else {
            return .unsupportedVersion(envelope.version)
        }

        do {
            return .loaded(try decoder.decode(RecordingMetadata.self, from: data))
        } catch {
            return .malformedMetadata
        }
    }
}

private extension EvidenceMetadataReader {
    struct VersionEnvelope: Decodable {
        let version: String
    }
}
