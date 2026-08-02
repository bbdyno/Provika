import Foundation

/// Executable policy describing the globally applicable offline Evidence Core.
struct EvidenceCoreOfflineBoundary {
    enum RequiredStage: String, CaseIterable, Codable, Hashable {
        case capture
        case originalStorage = "original-storage"
        case hash
        case canonicalClaim = "claim"
        case signature
        case independentVerification = "verification"
        case safeZIPExport = "ZIP-export"
    }

    enum OptionalPresentationDependency: String, CaseIterable, Codable, Hashable {
        case reverseGeocoding
        case analytics
        case presentationService
    }

    struct CoordinateConversion: Equatable, Codable {
        let sourceCoordinateSystem: String
        let targetCoordinateSystem: String
        let algorithm: String

        var isExplicit: Bool {
            [sourceCoordinateSystem, targetCoordinateSystem, algorithm]
                .allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
    }

    struct LocationObservation: Equatable, Codable {
        let rawLocation: RawLocation
        let presentation: PresentationLocation?
    }

    struct RawLocation: Equatable, Codable {
        let latitude: Double
        let longitude: Double
        let horizontalAccuracyMeters: Double
        let source: String
    }

    struct PresentationLocation: Equatable, Codable {
        let reverseGeocoding: String?
        let conversion: CoordinateConversion?
    }

    static let requiredStages = RequiredStage.allCases
    static let optionalPresentationDependencies = OptionalPresentationDependency.allCases
    static let shareBoundary = "iOS system share sheet"

    static func coreCanComplete(
        completedStages: Set<RequiredStage>,
        unavailablePresentationDependencies: Set<OptionalPresentationDependency>
    ) -> Bool {
        _ = unavailablePresentationDependencies
        return completedStages == Set(requiredStages)
    }

    static func preservesRawLocation(
        _ original: RawLocation,
        afterPresentation presentation: PresentationLocation?
    ) -> LocationObservation {
        LocationObservation(rawLocation: original, presentation: presentation)
    }
}
