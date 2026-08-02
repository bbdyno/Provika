import Foundation
import SwiftData
import XCTest
@testable import Provika

@MainActor
final class PhotoFirstVerticalSliceTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Recording.self,
            EvidenceProject.self,
            EvidenceRecord.self,
            configurations: configuration
        )
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
        super.tearDown()
    }

    func testVerifiedPackagePersistsOneEvidenceRecordAndReportsSuccess() throws {
        let context = try XCTUnwrap(context)
        var completion: PhotoEvidenceVerticalSliceCoordinator.Completion?
        let package = URL(fileURLWithPath: "/synthetic/photo-package")
        let claim = makeClaim()
        let coordinator = PhotoEvidenceVerticalSliceCoordinator(
            capture: { completion = $0 },
            persist: { [context] claim, packageDirectory in
                let record = EvidenceRecord(
                    id: "photo-package:\(claim.packageID.uuidString.lowercased())",
                    capturedAt: Date(timeIntervalSince1970: 1_767_323_045),
                    evidenceKindRawValue: "photo_evidence",
                    verificationStateRawValue: EvidenceVerificationState.verified.rawValue,
                    packagePath: packageDirectory.path,
                    contentHash: claim.media.sha256
                )
                context.insert(record)
                try context.save()
            }
        )

        coordinator.capturePhotoEvidence()
        XCTAssertEqual(coordinator.state, .capturing)
        guard let completion else {
            return XCTFail("Capture boundary did not retain its completion")
        }
        completion(.success(packageDirectory: package, claim: claim))

        XCTAssertEqual(coordinator.state, .succeeded)
        let records = try context.fetch(FetchDescriptor<EvidenceRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].packagePath, package.path)
        XCTAssertEqual(records[0].verificationState, .verified)
    }

    func testFailureDoesNotPersistEvidenceRecordAndReportsFailure() throws {
        var completion: PhotoEvidenceVerticalSliceCoordinator.Completion?
        var persistCalled = false
        let coordinator = PhotoEvidenceVerticalSliceCoordinator(
            capture: { completion = $0 },
            persist: { _, _ in persistCalled = true }
        )

        coordinator.capturePhotoEvidence()
        guard let completion else {
            return XCTFail("Capture boundary did not retain its completion")
        }
        completion(.failure(.verificationFailed(.invalidSignature)))

        XCTAssertEqual(coordinator.state, .failed)
        XCTAssertFalse(persistCalled)
        XCTAssertTrue(try context.fetch(FetchDescriptor<EvidenceRecord>()).isEmpty)
    }

    func testSecondRequestWhileCapturingDoesNotStartAnotherCameraCapture() {
        var captureCount = 0
        let coordinator = PhotoEvidenceVerticalSliceCoordinator(
            capture: { _ in captureCount += 1 },
            persist: { _, _ in }
        )

        coordinator.capturePhotoEvidence()
        coordinator.capturePhotoEvidence()

        XCTAssertEqual(captureCount, 1)
        XCTAssertEqual(coordinator.state, .capturing)
    }

    private func makeClaim() -> PhotoEvidenceClaimV2 {
        PhotoEvidenceClaimV2(
            packageID: UUID(uuidString: "A0B1C2D3-E4F5-4678-9ABC-DEF012345678")!,
            media: .init(fileName: "original.jpg", mediaType: "image/jpeg", pixelWidth: 2, pixelHeight: 3, sha256: "hash"),
            capture: .init(deviceTime: "2026-01-02T03:04:05.678Z"),
            app: .init(name: "Provika", version: "2.0.0", build: "200"),
            device: .init(model: "Synthetic iPhone", systemVersion: "iOS 18.0")
        )
    }
}
