import Foundation
import Security
import XCTest
@testable import Provika

final class VideoEvidencePipelineV2Tests: XCTestCase {
    private let packageID = UUID(uuidString: "A0B1C2D3-E4F5-4678-9ABC-DEF012345678")!

    func testGoldenClaim() throws {
        let fixture = try Data(contentsOf: fixtureURL())
        let claim = try JSONDecoder().decode(VideoEvidenceClaimV2.self, from: fixture)
        let canonicalFixture = try JSONSerialization.data(withJSONObject: JSONSerialization.jsonObject(with: fixture), options: [.sortedKeys, .withoutEscapingSlashes])
        XCTAssertEqual(try claim.canonicalData(), canonicalFixture)
        XCTAssertEqual(claim.schemaVersion, "2.0")
        XCTAssertEqual(claim.media.fileName, "original.mov")
    }

    func testCanonicalizationRepeatability() throws {
        let claim = try fixtureClaim()
        XCTAssertEqual(try claim.canonicalData(), try claim.canonicalData())
    }

    func testFinalizeOrderRecordingEndsBeforeHashingAndSigning() throws {
        let root = try makeRoot(); defer { remove(root) }
        var calls: [String] = []
        let pipeline = makePipeline(root: root, awaitFinalization: { url in calls.append("finalization"); return url }, validate: { _, _ in calls.append("playable-track"); return .success(self.observation()) }, finalize: { _, _, package in calls.append("hash-claim-signing"); try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true); return package })
        XCTAssertCompleted(pipeline.publish(try input(in: root)))
        XCTAssertEqual(calls, ["finalization", "playable-track", "hash-claim-signing"])
    }

    func testMediaValidationPassAndFailure() throws {
        let passingRoot = try makeRoot(); defer { remove(passingRoot) }
        XCTAssertCompleted(makePipeline(root: passingRoot).publish(try input(in: passingRoot)))

        let failingRoot = try makeRoot(); defer { remove(failingRoot) }
        let pipeline = makePipeline(root: failingRoot, validate: { _, _ in .failure(.missingVideoTrack) })
        XCTAssertEqual(pipeline.publish(try input(in: failingRoot)), .failed(.mediaValidationFailed(.missingVideoTrack)))
    }

    func testSilentRecordingPolicy() throws {
        let root = try makeRoot(); defer { remove(root) }
        var received: VideoAudioPermissionObservation?
        let pipeline = makePipeline(root: root, validate: { _, audio in received = audio; return .success(self.observation()) })
        XCTAssertCompleted(pipeline.publish(try input(in: root)))
        XCTAssertEqual(received?.microphoneAuthorization, .denied)
        XCTAssertEqual(received?.audioIncluded, false)
    }

    func testDeterministicHash() throws {
        let root = try makeRoot(); defer { remove(root) }
        let first = root.appendingPathComponent("first.mov")
        let second = root.appendingPathComponent("second.mov")
        let bytes = Data([0, 1, 2, 3, 4, 5])
        try bytes.write(to: first)
        try bytes.write(to: second)
        XCTAssertEqual(try HashCalculator.sha256(of: first), try HashCalculator.sha256(of: second))
    }

    func testAtomicPackageWrite() throws {
        let root = try makeRoot(); defer { remove(root) }
        let key = try makePrivateKey()
        let finalizer = VideoEvidencePackageFinalizerV2(signer: TestVideoSigner(key: key), publicKeyProvider: TestVideoPublicKey(key: key))
        let source = root.appendingPathComponent("source.mov")
        try Data([0, 1, 2, 3, 4, 5]).write(to: source)
        let package = root.appendingPathComponent("package", isDirectory: true)
        try finalizer.finalize(stagedVideoURL: source, claim: try fixtureClaim(), packageDirectory: package)
        XCTAssertEqual(Set(try FileManager.default.contentsOfDirectory(atPath: package.path)), Set(["original.mov", "claim.json", "signature.json", "manifest.json"]))
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
    }

    func testPartialPackageRollback() throws {
        let root = try makeRoot(); defer { remove(root) }
        let pipeline = makePipeline(root: root, finalize: { source, _, package in
            try FileManager.default.moveItem(at: source, to: package)
            throw TestVideoError.expected
        })
        XCTAssertEqual(pipeline.publish(try input(in: root)), .failed(.packageFinalizationFailed))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), [])
    }

    func testExistingDestinationPreserved() throws {
        let root = try makeRoot(); defer { remove(root) }
        let destination = root.appendingPathComponent(packageID.uuidString.lowercased(), isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let marker = destination.appendingPathComponent("marker")
        try Data("existing".utf8).write(to: marker)
        let pipeline = makePipeline(root: root, finalize: { _, _, _ in throw VideoEvidencePackageFinalizerV2.Error.packageAlreadyExists })
        XCTAssertEqual(pipeline.publish(try input(in: root)), .failed(.packageFinalizationFailed))
        XCTAssertEqual(try Data(contentsOf: marker), Data("existing".utf8))
    }

    func testVerificationBeforeDerivativeGeneration() throws {
        let root = try makeRoot(); defer { remove(root) }
        let pipeline = makePipeline(root: root, verifier: { _ in false })
        XCTAssertEqual(pipeline.publish(try input(in: root)), .failed(.verificationRejected))
        XCTAssertTrue(pipeline.stageLog.contains(.verifierAccepted) == false)
        XCTAssertTrue(pipeline.stageLog.contains(.derivativeEligible) == false)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), [])
    }

    func testInterruptedRecordingNotPublishable() throws {
        let root = try makeRoot(); defer { remove(root) }
        let pipeline = makePipeline(root: root, awaitFinalization: { _ in throw TestVideoError.expected })
        XCTAssertEqual(pipeline.publish(try input(in: root)), .failed(.finalizationFailed))
        XCTAssertFalse(pipeline.stageLog.contains(.atomicPackagePublished))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), [])
    }

    func testLegacyVideoCompatibility() throws {
        let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/legacy-recording-metadata-v1.json")
        XCTAssertNoThrow(try JSONDecoder().decode(RecordingMetadata.self, from: Data(contentsOf: fixture)))
    }

    private func makePipeline(
        root: URL,
        awaitFinalization: @escaping VideoEvidenceCapturePipelineV2.AwaitFinalization = { $0 },
        validate: @escaping VideoEvidenceCapturePipelineV2.Validate = { _, _ in
            .success(.init(
                videoTrack: .init(kind: "video", codec: "hvc1", durationMilliseconds: 10_000, width: 1920, height: 1080, channelCount: nil),
                audioTrack: nil,
                playable: true
            ))
        },
        finalize: @escaping VideoEvidenceCapturePipelineV2.Finalize = { _, _, package in try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true); return package },
        verifier: @escaping VideoEvidenceCapturePipelineV2.Verify = { _ in true }
    ) -> VideoEvidenceCapturePipelineV2 {
        .init(rootDirectory: root, metadata: .init(appVersion: "2.0.0", appBuild: "200", deviceModel: "Synthetic iPhone", systemVersion: "iOS 18.0"), packageIDProvider: { self.packageID }, awaitFinalization: awaitFinalization, validate: validate, finalize: finalize, verifier: verifier)
    }

    private func input(in root: URL) throws -> VideoEvidenceCaptureInputV2 {
        let url = root.appendingPathComponent("staging.mov")
        try Data([0, 1, 2, 3, 4, 5]).write(to: url)
        return .init(stagedVideoURL: url, capturedAtUTC: "2026-01-02T03:04:05.678Z", finalizedAtUTC: "2026-01-02T03:04:15.678Z", audioObservation: .init(microphoneAuthorization: .denied, silentRecordingDecision: .allowWhenMicrophoneDenied, audioIncluded: false))
    }

    private func observation() -> VideoEvidenceMediaObservation {
        .init(videoTrack: .init(kind: "video", codec: "hvc1", durationMilliseconds: 10_000, width: 1920, height: 1080, channelCount: nil), audioTrack: nil, playable: true)
    }

    private func fixtureURL() -> URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/video-evidence-claim-v2.json") }
    private func fixtureClaim() throws -> VideoEvidenceClaimV2 { try JSONDecoder().decode(VideoEvidenceClaimV2.self, from: Data(contentsOf: fixtureURL())) }
    private func makeRoot() throws -> URL { let url = FileManager.default.temporaryDirectory.appendingPathComponent("VideoEvidencePipelineV2Tests-\(UUID().uuidString)", isDirectory: true); try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true); return url }
    private func remove(_ url: URL) { try? FileManager.default.removeItem(at: url) }
    private func makePrivateKey() throws -> SecKey { let attributes: [String: Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom, kSecAttrKeySizeInBits as String: 256, kSecPrivateKeyAttrs as String: [kSecAttrIsPermanent as String: false]]; guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, nil) else { throw TestVideoError.expected }; return key }
    private func XCTAssertCompleted(_ result: VideoEvidenceCapturePipelineResultV2, file: StaticString = #filePath, line: UInt = #line) { guard case .completed = result else { return XCTFail("Expected completed, got \(result)", file: file, line: line) } }
}

private enum TestVideoError: Error { case expected }
private struct TestVideoSigner: PhotoEvidenceSigningV2 { let key: SecKey; func sign(_ data: Data) throws -> Data { guard let value = SecKeyCreateSignature(key, .ecdsaSignatureMessageX962SHA256, data as CFData, nil) else { throw TestVideoError.expected }; return value as Data } }
private struct TestVideoPublicKey: PhotoEvidencePublicKeyProvidingV2 { let key: SecKey; func publicKeyData() throws -> Data { guard let publicKey = SecKeyCopyPublicKey(key), let data = SecKeyCopyExternalRepresentation(publicKey, nil) else { throw TestVideoError.expected }; return data as Data } }
