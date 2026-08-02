import XCTest
@testable import Provika

final class ChinaOfflineDataBoundaryTests: XCTestCase {
    func testAirplaneCorePlanRequiresEveryOfflineStage() {
        let expected: Set<EvidenceCoreOfflineBoundary.RequiredStage> = [
            .capture, .originalStorage, .hash, .canonicalClaim, .signature,
            .independentVerification, .safeZIPExport
        ]
        XCTAssertEqual(Set(EvidenceCoreOfflineBoundary.requiredStages), expected)
        XCTAssertTrue(EvidenceCoreOfflineBoundary.coreCanComplete(
            completedStages: expected,
            unavailablePresentationDependencies: [.analytics, .reverseGeocoding]
        ))
    }

    func testMissingCaptureStorageHashClaimSignatureVerificationOrZIPBlocksCore() {
        let all = Set(EvidenceCoreOfflineBoundary.requiredStages)
        for stage in all {
            XCTAssertFalse(EvidenceCoreOfflineBoundary.coreCanComplete(
                completedStages: all.subtracting([stage]),
                unavailablePresentationDependencies: []
            ), "missing \(stage.rawValue)")
        }
    }

    func testAnalyticsAndReverseGeocodingAreOptionalPresentationDependencies() {
        XCTAssertEqual(
            Set(EvidenceCoreOfflineBoundary.optionalPresentationDependencies),
            Set([.analytics, .reverseGeocoding, .presentationService])
        )
        XCTAssertEqual(EvidenceCoreOfflineBoundary.shareBoundary, "iOS system share sheet")
    }

    func testRawLocationSurvivesOptionalCoordinatePresentation() {
        let raw = EvidenceCoreOfflineBoundary.RawLocation(
            latitude: 37.5665,
            longitude: 126.9780,
            horizontalAccuracyMeters: 5,
            source: "core-location-device"
        )
        let coordinate = EvidenceCoreOfflineBoundary.CoordinateConversion(
            sourceCoordinateSystem: "WGS84",
            targetCoordinateSystem: "GCJ02",
            algorithm: "documented-v1"
        )
        XCTAssertTrue(coordinate.isExplicit)
        let result = EvidenceCoreOfflineBoundary.preservesRawLocation(
            raw,
            afterPresentation: .init(reverseGeocoding: "optional label", conversion: coordinate)
        )
        XCTAssertEqual(result.rawLocation, raw)
        XCTAssertEqual(result.presentation?.conversion, coordinate)
    }

    func testIncompleteCoordinateConversionIsRejected() {
        XCTAssertFalse(EvidenceCoreOfflineBoundary.CoordinateConversion(
            sourceCoordinateSystem: "WGS84",
            targetCoordinateSystem: "",
            algorithm: "documented-v1"
        ).isExplicit)
    }
}
