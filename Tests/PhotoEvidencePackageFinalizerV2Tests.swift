import Foundation
import XCTest
@testable import Provika

final class PhotoEvidencePackageFinalizerV2Tests: XCTestCase {
    private let packageID = UUID(uuidString: "A0B1C2D3-E4F5-4678-9ABC-DEF012345678")!

    func testCanonicalClaimBytesAndDigestAreDeterministic() throws {
        let first = try finalizePackage()
        let second = try finalizePackage()
        defer { cleanup(first.root); cleanup(second.root) }

        let firstData = try Data(contentsOf: first.package.appendingPathComponent("claim.json"))
        let secondData = try Data(contentsOf: second.package.appendingPathComponent("claim.json"))
        XCTAssertEqual(firstData, secondData)
        XCTAssertEqual(HashCalculator.sha256(of: firstData), HashCalculator.sha256(of: secondData))
    }

    func testOriginalAndClaimDigestsMatchExactStoredBytes() throws {
        let result = try finalizePackage()
        defer { cleanup(result.root) }
        let envelope = try envelope(in: result.package)
        XCTAssertEqual(envelope.mediaHash.value, try HashCalculator.sha256(of: result.package.appendingPathComponent("original.jpg")))
        XCTAssertEqual(envelope.claimHash.value, try HashCalculator.sha256(of: result.package.appendingPathComponent("claim.json")))
    }

    func testSignatureEnvelopeCoversFrozenSigningPayload() throws {
        let signer = RecordingSigner()
        let result = try finalizePackage(signer: signer)
        defer { cleanup(result.root) }
        let envelope = try envelope(in: result.package)
        let expected = try EvidenceSigningPayloadV2(packageID: packageID, mediaSHA256: envelope.mediaHash.value, claimSHA256: envelope.claimHash.value)
        XCTAssertEqual(signer.signedPayloads, [expected.utf8Data])
        XCTAssertEqual(envelope.signature.value, Data("signature".utf8).base64EncodedString())
    }

    func testPublishesOnlyAfterAllArtifactsSucceed() throws {
        let result = try finalizePackage()
        defer { cleanup(result.root) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.package.appendingPathComponent("original.jpg").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.package.appendingPathComponent("claim.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.package.appendingPathComponent("signature.json").path))
    }

    func testFailureBeforePublishLeavesNoFinalPackage() throws {
        let root = try temporaryRoot()
        defer { cleanup(root) }
        let finalizer = makeFinalizer(signer: ThrowingSigner())
        XCTAssertThrowsError(try finalizer.finalize(originalPhotoURL: try photo(in: root), claim: claim(), packageDirectory: root.appendingPathComponent("package")))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("package").path))
    }

    func testFailureDuringGenerationCleansStaging() throws {
        let root = try temporaryRoot()
        defer { cleanup(root) }
        let finalizer = makeFinalizer(keyProvider: ThrowingKeyProvider())
        XCTAssertThrowsError(try finalizer.finalize(originalPhotoURL: try photo(in: root), claim: claim(), packageDirectory: root.appendingPathComponent("package")))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path).filter { $0.contains(".package.staging-") }, [])
    }

    func testExistingPackageIsNeverOverwritten() throws {
        let root = try temporaryRoot()
        defer { cleanup(root) }
        let package = root.appendingPathComponent("package")
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        let sentinel = package.appendingPathComponent("complete")
        try Data("keep".utf8).write(to: sentinel)
        XCTAssertThrowsError(try makeFinalizer().finalize(originalPhotoURL: try photo(in: root), claim: claim(), packageDirectory: package))
        XCTAssertEqual(try Data(contentsOf: sentinel), Data("keep".utf8))
    }

    func testNoIncompleteFinalPackageOnFailure() throws {
        let root = try temporaryRoot()
        defer { cleanup(root) }
        let package = root.appendingPathComponent("package")
        XCTAssertThrowsError(try makeFinalizer(signer: ThrowingSigner()).finalize(originalPhotoURL: try photo(in: root), claim: claim(), packageDirectory: package))
        XCTAssertFalse(FileManager.default.fileExists(atPath: package.path))
    }

    private func finalizePackage(signer: RecordingSigner = RecordingSigner()) throws -> (root: URL, package: URL) {
        let root = try temporaryRoot()
        let package = root.appendingPathComponent("package")
        try makeFinalizer(signer: signer).finalize(originalPhotoURL: photo(in: root), claim: claim(), packageDirectory: package)
        return (root, package)
    }

    private func makeFinalizer(signer: any PhotoEvidenceSigningV2 = RecordingSigner(), keyProvider: any PhotoEvidencePublicKeyProvidingV2 = StaticKeyProvider()) -> PhotoEvidencePackageFinalizerV2 {
        PhotoEvidencePackageFinalizerV2(signer: signer, publicKeyProvider: keyProvider)
    }

    private func claim() -> PhotoEvidenceClaimV2 {
        PhotoEvidenceClaimV2(packageID: packageID, media: .init(fileName: "original.jpg", mediaType: "image/jpeg", pixelWidth: 2, pixelHeight: 1, sha256: String(repeating: "0", count: 64)), capture: .init(deviceTime: "2026-01-02T03:04:05.678Z"), app: .init(name: "Provika", version: "2.0.0", build: "200"), device: .init(model: "Synthetic iPhone", systemVersion: "iOS 18.0"))
    }

    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PhotoEvidencePackageFinalizerV2Tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func photo(in root: URL) throws -> URL {
        let url = root.appendingPathComponent("input.jpg")
        try Data([0xFF, 0xD8, 0x00, 0x01, 0xFF, 0xD9]).write(to: url)
        return url
    }

    private func envelope(in package: URL) throws -> EvidenceSignatureEnvelopeV2 {
        try JSONDecoder().decode(EvidenceSignatureEnvelopeV2.self, from: Data(contentsOf: package.appendingPathComponent("signature.json")))
    }

    private func cleanup(_ root: URL) {
        try? FileManager.default.removeItem(at: root)
    }
}

private final class RecordingSigner: PhotoEvidenceSigningV2 {
    private(set) var signedPayloads: [Data] = []
    func sign(_ data: Data) throws -> Data { signedPayloads.append(data); return Data("signature".utf8) }
}

private struct StaticKeyProvider: PhotoEvidencePublicKeyProvidingV2 {
    func publicKeyData() throws -> Data { Data("public-key".utf8) }
}

private struct ThrowingSigner: PhotoEvidenceSigningV2 {
    func sign(_ data: Data) throws -> Data { throw TestError.expected }
}

private struct ThrowingKeyProvider: PhotoEvidencePublicKeyProvidingV2 {
    func publicKeyData() throws -> Data { throw TestError.expected }
}

private enum TestError: Swift.Error { case expected }
