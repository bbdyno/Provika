import Foundation

protocol PhotoEvidencePackageVerifyingV2 { func verify(packageDirectory: URL) -> PhotoEvidencePackageVerificationResultV2 }
extension PhotoEvidencePackageVerifierV2: PhotoEvidencePackageVerifyingV2 {}

/// Verifies frozen evidence before creating a ZIP reading copy; it performs no UI sharing.
final class PhotoEvidenceExportWorkflow {
    enum Outcome: Equatable { case success(URL), rejected(PhotoEvidencePackageVerificationResultV2), failed, cancelled }
    enum Error: Swift.Error { case destinationExists, invalidFrozenPackage, cancelled }
    private let verifier: any PhotoEvidencePackageVerifyingV2; private let fileManager: FileManager; private let zipExporter: SafeEvidenceZIPExporter
    private(set) var stateMachine: ExportWorkflowStateMachine
    init(verifier: any PhotoEvidencePackageVerifyingV2 = PhotoEvidencePackageVerifierV2(), fileManager: FileManager = .default, zipExporter: SafeEvidenceZIPExporter = .init(), stateMachine: ExportWorkflowStateMachine = .init()) { self.verifier = verifier; self.fileManager = fileManager; self.zipExporter = zipExporter; self.stateMachine = stateMachine }
    func export(
        packageDirectory: URL,
        destination: URL,
        operationID: EvidenceWorkflowOperationID,
        reportLanguage: EvidenceReportLanguage = .english,
        isCancelled: () -> Bool = { false }
    ) -> Outcome {
        guard case .accepted = stateMachine.transition(.start(operationID)) else { return .failed }
        if isCancelled() { _ = stateMachine.transition(.cancel(operationID)); return .cancelled }
        let result = verifier.verify(packageDirectory: packageDirectory)
        guard result == .valid else { _ = stateMachine.transition(.fail(operationID)); return .rejected(result) }
        let staging = destination.deletingLastPathComponent().appendingPathComponent(".\(destination.lastPathComponent).staging-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: staging) }
        do {
            guard !fileManager.fileExists(atPath: destination.path) else { throw Error.destinationExists }
            let claimURL = packageDirectory.appendingPathComponent("claim.json")
            let claimData = try safeData(claimURL)
            let claim = try JSONDecoder().decode(PhotoEvidenceClaimV2.self, from: claimData)
            guard safeArtifactName(claim.media.fileName) else { throw Error.invalidFrozenPackage }
            let mediaData = try safeData(packageDirectory.appendingPathComponent(claim.media.fileName))
            let signatureData = try safeData(packageDirectory.appendingPathComponent("signature.json"))
            let manifestURL = packageDirectory.appendingPathComponent("manifest.json")
            let manifestData = fileManager.fileExists(atPath: manifestURL.path) ? try safeData(manifestURL) : nil
            if isCancelled() { throw Error.cancelled }
            try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
            // Snapshot the verified package bytes before generating a reader copy. This avoids
            // a second read of a mutable source and keeps the ZIP entries byte-for-byte exact.
            let inputs = staging.appendingPathComponent("inputs", isDirectory: true)
            try fileManager.createDirectory(at: inputs, withIntermediateDirectories: false)
            let stagedMedia = inputs.appendingPathComponent(claim.media.fileName)
            let stagedClaim = inputs.appendingPathComponent("claim.json")
            let stagedSignature = inputs.appendingPathComponent("signature.json")
            let stagedManifest = inputs.appendingPathComponent("manifest.json")
            try mediaData.write(to: stagedMedia, options: .atomic)
            try claimData.write(to: stagedClaim, options: .atomic)
            try signatureData.write(to: stagedSignature, options: .atomic)
            try manifestData?.write(to: stagedManifest, options: .atomic)
            let report = staging.appendingPathComponent("Photo Evidence Report.pdf")
            try EvidencePDFReportGenerator.write(claim: claim, language: reportLanguage, to: report)
            if isCancelled() { throw Error.cancelled }
            var entries: [SafeEvidenceZIPExporter.Entry] = [
                .init(name: "EvidencePackage/\(claim.media.fileName)", sourceURL: stagedMedia),
                .init(name: "EvidencePackage/claim.json", sourceURL: stagedClaim),
                .init(name: "EvidencePackage/signature.json", sourceURL: stagedSignature)
            ]
            if manifestData != nil { entries.append(.init(name: "EvidencePackage/manifest.json", sourceURL: stagedManifest)) }
            entries.append(.init(name: "Photo Evidence Report.pdf", sourceURL: report))
            try zipExporter.write(entries: entries, to: staging.appendingPathComponent("archive.zip"))
            if isCancelled() { throw Error.cancelled }; try fileManager.moveItem(at: staging.appendingPathComponent("archive.zip"), to: destination); _ = stateMachine.transition(.complete(operationID)); return .success(destination)
        } catch Error.cancelled { _ = stateMachine.transition(.cancel(operationID)); return .cancelled } catch { _ = stateMachine.transition(.fail(operationID)); return .failed }
    }
    private func safeData(_ url: URL) throws -> Data {
        // Reject links before inspecting attributes because attribute lookup may
        // otherwise resolve them. Signed evidence inputs must be ordinary files.
        guard (try? fileManager.destinationOfSymbolicLink(atPath: url.path)) == nil else {
            throw Error.invalidFrozenPackage
        }
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular else {
            throw Error.invalidFrozenPackage
        }
        return try Data(contentsOf: url, options: .mappedIfSafe)
    }
    private func safeArtifactName(_ name: String) -> Bool {
        !name.isEmpty && name != "." && name != ".." &&
            !name.contains("/") && !name.contains("\\") &&
            URL(fileURLWithPath: name).lastPathComponent == name
    }
}
