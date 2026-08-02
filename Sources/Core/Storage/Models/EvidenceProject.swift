import Foundation
import SwiftData

@Model
final class EvidenceProject {
    @Attribute(.unique) var id: String
    var schemaVersion: Int
    var createdAt: Date
    var updatedAt: Date
    var name: String
    @Relationship(inverse: \EvidenceRecord.project) var records: [EvidenceRecord]

    init(
        id: String = UUID().uuidString.lowercased(),
        schemaVersion: Int = 1,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        name: String
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.name = name
        self.records = []
    }
}
