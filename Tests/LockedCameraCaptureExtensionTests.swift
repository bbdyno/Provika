import Foundation
import XCTest
@testable import Provika

@MainActor
final class LockedCameraCaptureExtensionTests: XCTestCase {
    func testPendingHandoffPublishesAtomically() throws {
        let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let pending = try LockedCapturePendingHandoffWriter.publish(mediaData: Data([1, 2, 3]), fileExtension: "jpg", mediaType: "image/jpeg", to: root)
        XCTAssertTrue(pending.lastPathComponent.hasPrefix("pending-"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: pending.appendingPathComponent("handoff.json").path))
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: root.path).contains { $0.hasPrefix(".staging-") })
    }

    func testExtensionNeverSigns() throws {
        let source = try [
            text("Sources/LockedCaptureExtension/ProvikaLockedCaptureExtension.swift"),
            text("Sources/LockedCaptureExtension/LockedCaptureView.swift"),
            text("Sources/LockedCaptureExtension/LockedCaptureCameraModel.swift"),
            text("Sources/Shared/Intents/ProvikaCameraCaptureIntent.swift")
        ].joined(separator: "\n")
        for forbidden in ["SignatureService", "SecItem", "Keychain", "privateKey", "sign("] {
            XCTAssertFalse(source.contains(forbidden))
        }
        XCTAssertFalse(LockedStateSigningKeyPolicy.extensionMaySealEvidence)
    }

    func testParentImportIsIdempotent() async throws {
        let fixture = try handoffFixture(); defer { try? FileManager.default.removeItem(at: fixture) }
        var persisted = 0
        let coordinator = coordinator(persist: { _, _ in persisted += 1 })
        let first = await coordinator.importSessionContent(at: fixture)
        let second = await coordinator.importSessionContent(at: fixture)
        guard case .imported = first, case .duplicate = second else { return XCTFail("expected imported then duplicate") }
        XCTAssertEqual(persisted, 1)
    }

    func testMalformedOrUnsafeHandoffQuarantines() async throws {
        let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let pending = root.appendingPathComponent("pending-malformed")
        try FileManager.default.createDirectory(at: pending, withIntermediateDirectories: false)
        try Data("{bad".utf8).write(to: pending.appendingPathComponent("handoff.json"))
        var quarantined = 0
        let coordinator = LockedCaptureImportCoordinator(dependencies: .init(protectedDataAvailable: { true }, verify: { _, _ in true }, persist: { _, _ in }, quarantine: { _, _ in quarantined += 1 }))
        guard case .quarantined = await coordinator.importSessionContent(at: root) else { return XCTFail("expected quarantine") }
        XCTAssertEqual(quarantined, 1)
    }

    func testProtectedDataUnavailableStaysPending() async throws {
        let root = try handoffFixture(); defer { try? FileManager.default.removeItem(at: root) }
        let coordinator = LockedCaptureImportCoordinator(dependencies: .init(protectedDataAvailable: { false }))
        let result = await coordinator.importSessionContent(at: root)
        XCTAssertEqual(result, .pending("protectedDataUnavailable"))
    }

    func testVerifierFailureNeverPersistsVerifiedEvidence() async throws {
        let root = try handoffFixture(); defer { try? FileManager.default.removeItem(at: root) }
        var persisted = 0
        let coordinator = LockedCaptureImportCoordinator(dependencies: .init(protectedDataAvailable: { true }, verify: { _, _ in false }, persist: { _, _ in persisted += 1 }, quarantine: { _, _ in }))
        guard case .quarantined = await coordinator.importSessionContent(at: root) else { return XCTFail("expected quarantine") }
        XCTAssertEqual(persisted, 0)
    }

    func testDurableSuccessInvalidatesSessionContent() async throws {
        let root = try handoffFixture(); defer { try? FileManager.default.removeItem(at: root) }
        var invalidated = 0
        let coordinator = coordinator()
        guard case .imported = await coordinator.importSessionContent(at: root, invalidateSessionContent: { invalidated += 1 }) else { return XCTFail("expected import") }
        XCTAssertEqual(invalidated, 1)
    }

    func testCancellationAndRetry() async throws {
        let root = try handoffFixture(); defer { try? FileManager.default.removeItem(at: root) }
        var verifierReady = false
        let coordinator = LockedCaptureImportCoordinator(dependencies: .init(protectedDataAvailable: { true }, verify: { _, _ in verifierReady ? true : nil }, persist: { _, _ in }, quarantine: { _, _ in }))
        guard case .pending = await coordinator.importSessionContent(at: root) else { return XCTFail("expected pending") }
        verifierReady = true
        guard case .imported = await coordinator.importSessionContent(at: root) else { return XCTFail("expected retry import") }
    }

    func testEveryCaptureInSessionIsImportedBeforeInvalidation() async throws {
        let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        for byte in [UInt8(1), 2, 3] {
            _ = try LockedCapturePendingHandoffWriter.publish(mediaData: Data([byte]), fileExtension: "jpg", mediaType: "image/jpeg", to: root)
        }
        var persisted = 0, invalidated = 0
        let coordinator = coordinator(persist: { _, _ in persisted += 1 })
        guard case .imported = await coordinator.importSessionContent(at: root, invalidateSessionContent: { invalidated += 1 }) else { return XCTFail("expected import") }
        XCTAssertEqual(persisted, 3)
        XCTAssertEqual(invalidated, 1)
    }

    func testSealFailureKeepsSessionContentForRetry() async throws {
        let root = try handoffFixture(); defer { try? FileManager.default.removeItem(at: root) }
        struct SealFailure: Error {}
        var shouldFail = true, invalidated = 0
        let coordinator = coordinator(persist: { _, _ in if shouldFail { throw SealFailure() } })
        guard case .pending = await coordinator.importSessionContent(at: root, invalidateSessionContent: { invalidated += 1 }) else { return XCTFail("expected pending") }
        XCTAssertEqual(invalidated, 0)
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: root.path).filter { $0.hasPrefix("pending-") }.isEmpty)
        shouldFail = false
        guard case .imported = await coordinator.importSessionContent(at: root, invalidateSessionContent: { invalidated += 1 }) else { return XCTFail("expected retry import") }
        XCTAssertEqual(invalidated, 1)
    }

    func testHandoffCarriesExtensionCaptureTime() throws {
        let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let capturedAt = Date(timeIntervalSince1970: 1_760_000_000.25)
        let pending = try LockedCapturePendingHandoffWriter.publish(mediaData: Data([1]), fileExtension: "jpg", mediaType: "image/jpeg", capturedAt: capturedAt, to: root)
        let handoff = try JSONDecoder().decode(LockedCaptureHandoff.self, from: Data(contentsOf: pending.appendingPathComponent("handoff.json")))
        XCTAssertEqual(try XCTUnwrap(handoff.capturedDate).timeIntervalSince1970, capturedAt.timeIntervalSince1970, accuracy: 0.001)
    }

    func testFileBasedPublishMovesMediaIntoHandoff() throws {
        let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let recording = root.appendingPathComponent(".recording-test.mov")
        try Data([9, 9, 9, 9]).write(to: recording)
        let pending = try LockedCapturePendingHandoffWriter.publish(mediaFileAt: recording, fileExtension: "mov", mediaType: "video/quicktime", capturedAt: Date(), to: root)
        XCTAssertFalse(FileManager.default.fileExists(atPath: recording.path))
        let handoff = try JSONDecoder().decode(LockedCaptureHandoff.self, from: Data(contentsOf: pending.appendingPathComponent("handoff.json")))
        XCTAssertEqual(handoff.byteCount, 4)
        XCTAssertEqual(handoff.mediaFileName, "original.mov")
    }

    func testHandoffWithoutCaptureTimeIsRejectedInsteadOfBackfilled() async throws {
        let root = try handoffFixture(); defer { try? FileManager.default.removeItem(at: root) }
        let pending = try XCTUnwrap(try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).first { $0.lastPathComponent.hasPrefix("pending-") })
        let handoff = try JSONDecoder().decode(LockedCaptureHandoff.self, from: Data(contentsOf: pending.appendingPathComponent("handoff.json")))
        XCTAssertNil(handoff.capturedDate)
        let verified = await LockedCaptureEvidenceSealer.verify(pending.appendingPathComponent(handoff.mediaFileName), handoff)
        XCTAssertEqual(verified, false)
    }

    func testUnsupportedCapabilityPreservesNormalAppFlow() throws {
        let app = try text("Sources/App/ProvikaApp.swift")
        let camera = try text("Sources/Features/Camera/Views/CameraView.swift")
        XCTAssertTrue(app.contains("RootView()"))
        XCTAssertTrue(camera.contains("CameraPreviewView"))
    }

    private func coordinator(persist: @escaping (URL, LockedCaptureHandoff) async throws -> Void = { _, _ in }) -> LockedCaptureImportCoordinator {
        LockedCaptureImportCoordinator(dependencies: .init(protectedDataAvailable: { true }, verify: { _, _ in true }, persist: persist, quarantine: { _, _ in }))
    }

    private func handoffFixture() throws -> URL {
        let root = try temporaryDirectory()
        _ = try LockedCapturePendingHandoffWriter.publish(mediaData: Data([1, 2, 3]), fileExtension: "jpg", mediaType: "image/jpeg", to: root)
        return root
    }

    private func temporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func repositoryURL(_ path: String) -> URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(path) }
    private func text(_ path: String) throws -> String { try String(contentsOf: repositoryURL(path), encoding: .utf8) }
}
