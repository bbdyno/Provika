import Foundation

enum ChinaReleaseStatus: String, Codable, Equatable {
    case ready = "READY"
    case blocked = "BLOCKED"
    case abstain = "ABSTAIN"
}

struct ChinaReadinessEvidence: Equatable {
    var evidenceDigest: String?
    var binary: Bool?
    var global: Bool?
    var chinaMainland: Bool?
    var ownerEvidence: String?
    var appStoreConnect: String?
    var humanReview: String?
}

struct ChinaAppStoreReadiness: Equatable {
    let binary: ChinaReleaseStatus
    let global: ChinaReleaseStatus
    let chinaMainland: ChinaReleaseStatus

    static func evaluate(_ evidence: ChinaReadinessEvidence) -> ChinaAppStoreReadiness {
        let binaryStatus = status(for: evidence.binary, evidenceDigest: evidence.evidenceDigest)
        let globalStatus = status(for: evidence.global, evidenceDigest: evidence.evidenceDigest)

        let chinaStatus: ChinaReleaseStatus
        if evidence.evidenceDigest == nil || evidence.chinaMainland == nil ||
            evidence.ownerEvidence == nil || evidence.appStoreConnect == nil || evidence.humanReview == nil {
            chinaStatus = .abstain
        } else if evidence.chinaMainland == false {
            chinaStatus = .blocked
        } else {
            chinaStatus = .ready
        }
        return .init(binary: binaryStatus, global: globalStatus, chinaMainland: chinaStatus)
    }

    private static func status(for decision: Bool?, evidenceDigest: String?) -> ChinaReleaseStatus {
        guard evidenceDigest != nil, let decision else { return .abstain }
        return decision ? .ready : .blocked
    }
}
