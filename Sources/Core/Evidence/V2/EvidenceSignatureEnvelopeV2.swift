import Foundation

struct EvidenceSignatureEnvelopeV2: Codable, Equatable {
    let schemaVersion: String
    let packageID: UUID
    let mediaHash: Hash
    let claimHash: Hash
    let signature: Signature
    let publicKey: PublicKey

    init(packageID: UUID, mediaHash: Hash, claimHash: Hash, signature: Signature, publicKey: PublicKey) {
        self.schemaVersion = "2.0"
        self.packageID = packageID
        self.mediaHash = mediaHash
        self.claimHash = claimHash
        self.signature = signature
        self.publicKey = publicKey
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, packageID, mediaHash, claimHash, signature, publicKey
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(String.self, forKey: .schemaVersion)
        guard schemaVersion == "2.0" else {
            throw DecodingError.dataCorruptedError(forKey: .schemaVersion, in: container, debugDescription: "Unsupported schemaVersion: \(schemaVersion)")
        }

        self.schemaVersion = schemaVersion
        self.packageID = try container.decode(UUID.self, forKey: .packageID)
        self.mediaHash = try container.decode(Hash.self, forKey: .mediaHash)
        self.claimHash = try container.decode(Hash.self, forKey: .claimHash)
        self.signature = try container.decode(Signature.self, forKey: .signature)
        self.publicKey = try container.decode(PublicKey.self, forKey: .publicKey)
    }

    struct Hash: Codable, Equatable {
        let algorithm: String
        let value: String

        init(value: String) {
            self.algorithm = "sha256"
            self.value = value
        }

        private enum CodingKeys: String, CodingKey {
            case algorithm, value
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let algorithm = try container.decode(String.self, forKey: .algorithm)
            guard algorithm == "sha256" else {
                throw DecodingError.dataCorruptedError(forKey: .algorithm, in: container, debugDescription: "Unsupported hash algorithm: \(algorithm)")
            }

            self.algorithm = algorithm
            self.value = try container.decode(String.self, forKey: .value)
        }
    }

    struct Signature: Codable, Equatable {
        let algorithm: String
        let payloadFormat: String
        let value: String

        init(value: String) {
            self.algorithm = "ecdsa-p256-sha256-x962"
            self.payloadFormat = "provika-evidence-signature-v2"
            self.value = value
        }

        private enum CodingKeys: String, CodingKey {
            case algorithm, payloadFormat, value
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let algorithm = try container.decode(String.self, forKey: .algorithm)
            guard algorithm == "ecdsa-p256-sha256-x962" else {
                throw DecodingError.dataCorruptedError(forKey: .algorithm, in: container, debugDescription: "Unsupported signature algorithm: \(algorithm)")
            }
            let payloadFormat = try container.decode(String.self, forKey: .payloadFormat)
            guard payloadFormat == "provika-evidence-signature-v2" else {
                throw DecodingError.dataCorruptedError(forKey: .payloadFormat, in: container, debugDescription: "Unsupported signature payload format: \(payloadFormat)")
            }

            self.algorithm = algorithm
            self.payloadFormat = payloadFormat
            self.value = try container.decode(String.self, forKey: .value)
        }
    }

    struct PublicKey: Codable, Equatable {
        let format: String
        let value: String

        init(value: String) {
            self.format = "p256-x963"
            self.value = value
        }

        private enum CodingKeys: String, CodingKey {
            case format, value
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let format = try container.decode(String.self, forKey: .format)
            guard format == "p256-x963" else {
                throw DecodingError.dataCorruptedError(forKey: .format, in: container, debugDescription: "Unsupported public key format: \(format)")
            }

            self.format = format
            self.value = try container.decode(String.self, forKey: .value)
        }
    }
}
