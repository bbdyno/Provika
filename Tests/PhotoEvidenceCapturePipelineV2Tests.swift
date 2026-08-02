import CoreLocation
import Foundation
import UIKit
import XCTest
@testable import Provika

final class PhotoEvidenceCapturePipelineV2Tests: XCTestCase {
    private let packageID = UUID(uuidString: "A0B1C2D3-E4F5-4678-9ABC-DEF012345678")!
    private let capturedAt = Date(timeIntervalSince1970: 1_767_323_045.678)
    private let metadata = PhotoEvidenceCaptureMetadataV2(appName: "Provika", appVersion: "2.0.0", appBuild: "200", deviceModel: "Synthetic iPhone", systemVersion: "iOS 18.0")

    // Success without location preserves exact frozen metadata.
    func testSuccessWithoutLocationBuildsExactMetadata() throws {
        let root = try makeRoot()
        defer { remove(root) }
        var capturedClaim: PhotoEvidenceClaimV2?
        let pipeline = makePipeline(root: root, finalizer: { _, claim, package in
            capturedClaim = claim
            try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
            return package
        })

        let outcome = wait(for: { completion in pipeline.capture(result(), location: nil, completion: completion) })
        guard case let .success(packageDirectory, _) = outcome else { return XCTFail("Expected a valid package") }
        XCTAssertEqual(packageDirectory, root.appendingPathComponent(packageID.uuidString.lowercased()))
        let claim = try XCTUnwrap(capturedClaim)
        XCTAssertEqual(claim.media.fileName, "original.jpg")
        XCTAssertEqual(claim.media.mediaType, "image/jpeg")
        XCTAssertEqual(claim.media.pixelWidth, 2)
        XCTAssertEqual(claim.media.pixelHeight, 3)
        XCTAssertEqual(claim.capture.deviceTime, "2026-01-02T03:04:05.678Z")
        XCTAssertEqual(claim.app, .init(name: "Provika", version: "2.0.0", build: "200"))
        XCTAssertEqual(claim.device, .init(model: "Synthetic iPhone", systemVersion: "iOS 18.0"))
        XCTAssertNil(claim.location)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(".\(packageID.uuidString.lowercased()).jpg").path))
    }

    func testSuccessWithLocationCopiesAllCaptureTimeMeasurements() throws {
        let root = try makeRoot()
        defer { remove(root) }
        var capturedClaim: PhotoEvidenceClaimV2?
        let location = CLLocation(coordinate: .init(latitude: 37.5665, longitude: 126.978), altitude: 38.2, horizontalAccuracy: 4.5, verticalAccuracy: 6.7, course: 91.25, speed: 12.3, timestamp: capturedAt)
        let pipeline = makePipeline(root: root, finalizer: { _, claim, package in
            capturedClaim = claim
            try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
            return package
        })

        _ = wait(for: { completion in pipeline.capture(result(), location: location, completion: completion) })
        let locationClaim = try XCTUnwrap(capturedClaim?.location)
        XCTAssertEqual(locationClaim.lat, 37.5665)
        XCTAssertEqual(locationClaim.lng, 126.978)
        XCTAssertEqual(locationClaim.horizontalAccuracyMeters, 4.5)
        XCTAssertEqual(locationClaim.altitudeMeters, 38.2)
        XCTAssertEqual(locationClaim.verticalAccuracyMeters, 6.7)
        XCTAssertEqual(locationClaim.headingDegrees, 91.25)
        XCTAssertEqual(locationClaim.speedMetersPerSecond, 12.3)
    }

    func testBusyCaptureIsRejectedWhileAnotherCaptureIsFinalizing() throws {
        let root = try makeRoot()
        defer { remove(root) }
        let started = expectation(description: "started")
        let unblock = DispatchSemaphore(value: 0)
        let pipeline = makePipeline(root: root, finalizer: { _, _, package in
            started.fulfill()
            _ = unblock.wait(timeout: .now() + 2)
            try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
            return package
        })
        let first = expectation(description: "first")
        pipeline.capture(result(), location: nil) { _ in first.fulfill() }
        wait(for: [started], timeout: 1)
        XCTAssertEqual(wait(for: { completion in pipeline.capture(result(), location: nil, completion: completion) }), .failure(.busy))
        unblock.signal()
        wait(for: [first], timeout: 1)
    }

    func testMalformedPhotoDataFailsBeforeFinalizationAndLeavesNoFiles() throws {
        let root = try makeRoot()
        defer { remove(root) }
        let pipeline = makePipeline(root: root, finalizer: { _, _, _ in XCTFail("must not finalize"); throw TestFailure.expected })
        let bad = PhotoEvidenceCaptureResultV2(fileData: Data("not-a-photo".utf8), pixelWidth: 2, pixelHeight: 3, mediaType: "image/jpeg", capturedAt: capturedAt)
        XCTAssertEqual(wait(for: { completion in pipeline.capture(bad, location: nil, completion: completion) }), .failure(.malformedPhotoData))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), [])
    }

    // Failure cleanup removes temporary bytes and incomplete output.
    func testFinalizerFailureCleansTemporaryBytesAndIncompleteOutput() throws {
        let root = try makeRoot()
        defer { remove(root) }
        let pipeline = makePipeline(root: root, finalizer: { _, _, package in
            try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
            throw TestFailure.expected
        })
        XCTAssertEqual(wait(for: { completion in pipeline.capture(result(), location: nil, completion: completion) }), .failure(.finalizationFailed))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), [])
    }

    func testVerifierFailureRemovesPublishedIncompleteOutput() throws {
        let root = try makeRoot()
        defer { remove(root) }
        let pipeline = makePipeline(root: root, verifier: { _ in .invalidSignature }, finalizer: { _, _, package in
            try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
            return package
        })
        XCTAssertEqual(wait(for: { completion in pipeline.capture(result(), location: nil, completion: completion) }), .failure(.verificationFailed(.invalidSignature)))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), [])
    }

    func testRepeatableInputsProduceIdenticalFrozenClaims() throws {
        let first = try makeRoot(); defer { remove(first) }
        let second = try makeRoot(); defer { remove(second) }
        var claims: [PhotoEvidenceClaimV2] = []
        for root in [first, second] {
            let pipeline = makePipeline(root: root, finalizer: { _, claim, package in
                claims.append(claim)
                try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
                return package
            })
            _ = wait(for: { completion in pipeline.capture(result(), location: nil, completion: completion) })
        }
        XCTAssertEqual(claims, [claims[0], claims[0]])
    }

    private func makePipeline(root: URL, verifier: @escaping PhotoEvidenceCapturePipelineV2.Verify = { _ in .valid }, finalizer: @escaping PhotoEvidenceCapturePipelineV2.Finalize) -> PhotoEvidenceCapturePipelineV2 {
        PhotoEvidenceCapturePipelineV2(rootDirectory: root, metadata: metadata, packageIDProvider: { self.packageID }, finalizer: finalizer, verifier: verifier)
    }

    private func result() -> PhotoEvidenceCaptureResultV2 {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 3), format: format)
        let data = renderer.jpegData(withCompressionQuality: 1) { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 3))
        }
        return .init(fileData: data, pixelWidth: 2, pixelHeight: 3, mediaType: "image/jpeg", capturedAt: capturedAt)
    }

    private func wait(for start: (@escaping (PhotoEvidenceCapturePipelineResultV2) -> Void) -> Void) -> PhotoEvidenceCapturePipelineResultV2 {
        let expectation = expectation(description: "completion")
        var outcome: PhotoEvidenceCapturePipelineResultV2?
        start { result in outcome = result; expectation.fulfill() }
        wait(for: [expectation], timeout: 2)
        return outcome!
    }

    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PhotoEvidenceCapturePipelineV2Tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func remove(_ root: URL) { try? FileManager.default.removeItem(at: root) }
}

private enum TestFailure: Error { case expected }
