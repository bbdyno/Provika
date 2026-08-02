import Foundation

struct EvidenceSigningPayloadV2: Equatable {
    let packageID: UUID
    let mediaSHA256: String
    let claimSHA256: String

    enum Error: Swift.Error, Equatable {
        case mediaSHA256ContainsUppercase
        case mediaSHA256WrongLength
        case mediaSHA256ContainsNonHex
        case claimSHA256ContainsUppercase
        case claimSHA256WrongLength
        case claimSHA256ContainsNonHex
    }

    init(packageID: UUID, mediaSHA256: String, claimSHA256: String) throws {
        try Self.validate(mediaSHA256, field: .media)
        try Self.validate(claimSHA256, field: .claim)

        self.packageID = packageID
        self.mediaSHA256 = mediaSHA256
        self.claimSHA256 = claimSHA256
    }

    var string: String {
        """
        Provika-Evidence-Package-Signature-V2
        package-id:\(packageID.uuidString.lowercased())
        media-sha256:\(mediaSHA256)
        claim-sha256:\(claimSHA256)

        """
    }

    var utf8Data: Data {
        Data(string.utf8)
    }

    private enum HashField {
        case media
        case claim
    }

    private static func validate(_ value: String, field: HashField) throws {
        if value.utf8.count != 64 {
            throw field == .media ? Error.mediaSHA256WrongLength : Error.claimSHA256WrongLength
        }

        for byte in value.utf8 {
            if (65...70).contains(byte) {
                throw field == .media ? Error.mediaSHA256ContainsUppercase : Error.claimSHA256ContainsUppercase
            }
            guard (48...57).contains(byte) || (97...102).contains(byte) else {
                throw field == .media ? Error.mediaSHA256ContainsNonHex : Error.claimSHA256ContainsNonHex
            }
        }
    }
}
