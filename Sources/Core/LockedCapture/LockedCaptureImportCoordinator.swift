import Foundation
import LockedCameraCapture
import UIKit

@MainActor
final class LockedCaptureImportCoordinator {
    enum Outcome: Equatable {
        case imported(UUID)
        case duplicate(UUID)
        case pending(String)
        case quarantined(String)
    }

    struct Dependencies {
        var protectedDataAvailable: () -> Bool = { false }
        /// nil means the parent sealing/verifier dependency is not ready yet;
        /// false is a completed independent-verifier rejection.
        var verify: (URL, LockedCaptureHandoff) -> Bool? = { _, _ in nil }
        var persist: (URL, LockedCaptureHandoff) throws -> Void = { _, _ in }
        var quarantine: (URL, String) throws -> Void = { _, _ in }
    }

    private let fileManager: FileManager
    private let maximumBytes: Int
    private let dependencies: Dependencies
    // Process-local idempotent replay fence; durable persistence remains the
    // parent pipeline's authority for cross-launch de-duplication.
    private var importedIDs = Set<UUID>()
    private var observationTask: Task<Void, Never>?

    init(
        fileManager: FileManager = .default,
        maximumBytes: Int = LockedCapturePendingHandoffWriter.maximumBytes,
        dependencies: Dependencies? = nil
    ) {
        self.fileManager = fileManager
        self.maximumBytes = maximumBytes
        self.dependencies = dependencies ?? .init(
            protectedDataAvailable: { UIApplication.shared.isProtectedDataAvailable }
        )
    }

    deinit { observationTask?.cancel() }

    func startObserving() {
        guard observationTask == nil else { return }
        let manager = LockedCameraCaptureManager.shared
        observationTask = Task { [weak self] in
            guard let self else { return }
            for url in manager.sessionContentURLs {
                _ = await self.importSessionContent(at: url) {
                    try await manager.invalidateSessionContent(at: url)
                }
            }
            for await update in manager.sessionContentUpdates {
                guard !Task.isCancelled else { return }
                switch update {
                case .initial(let urls):
                    for url in urls {
                        _ = await self.importSessionContent(at: url) {
                            try await manager.invalidateSessionContent(at: url)
                        }
                    }
                case .added(let url):
                    _ = await self.importSessionContent(at: url) {
                        try await manager.invalidateSessionContent(at: url)
                    }
                case .removed:
                    break
                @unknown default:
                    break
                }
            }
        }
    }

    func importSessionContent(
        at sessionContentURL: URL,
        invalidateSessionContent: () async throws -> Void = {}
    ) async -> Outcome {
        guard dependencies.protectedDataAvailable() else {
            return .pending(LockedCaptureParentImportPolicy.protectedDataUnavailable)
        }
        do {
            let pendingDirectories = try fileManager.contentsOfDirectory(
                at: sessionContentURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ).filter { $0.lastPathComponent.hasPrefix("pending-") }
            guard let directory = pendingDirectories.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }).first else {
                return .pending("no pending handoff")
            }
            return await importHandoff(directory, invalidateSessionContent: invalidateSessionContent)
        } catch {
            return .quarantined("handoff enumeration failed")
        }
    }

    private func importHandoff(
        _ directory: URL,
        invalidateSessionContent: () async throws -> Void
    ) async -> Outcome {
        do {
            let handoffURL = directory.appendingPathComponent("handoff.json")
            guard isRegularFile(handoffURL) else { return try quarantine(directory, reason: "manifest is not a regularFile") }
            let data = try Data(contentsOf: handoffURL)
            let handoff = try JSONDecoder().decode(LockedCaptureHandoff.self, from: data)
            guard handoff.schemaVersion == LockedCaptureHandoff.currentSchemaVersion else {
                return try quarantine(directory, reason: "unsupported schemaVersion")
            }
            guard safeFileName(handoff.mediaFileName) else { return try quarantine(directory, reason: "unsafe handoff path") }
            let mediaURL = directory.appendingPathComponent(handoff.mediaFileName)
            guard isRegularFile(mediaURL) else { return try quarantine(directory, reason: "media is not a regularFile") }
            let size = try mediaURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? -1
            guard size == handoff.byteCount, size > 0, size <= maximumBytes else {
                return try quarantine(directory, reason: "maximumBytes or size mismatch")
            }
            if importedIDs.contains(handoff.handoffID) {
                try await invalidateSessionContent()
                return .duplicate(handoff.handoffID)
            }
            guard let independentlyVerified = dependencies.verify(mediaURL, handoff) else {
                return .pending("parent verifier unavailable")
            }
            guard independentlyVerified else { return try quarantine(directory, reason: "verify rejected handoff") }
            try dependencies.persist(mediaURL, handoff)
            importedIDs.insert(handoff.handoffID)
            // Invalidation occurs only after persist returns durable success.
            try await invalidateSessionContent()
            return .imported(handoff.handoffID)
        } catch {
            return (try? quarantine(directory, reason: "malformed handoff")) ?? .quarantined("malformed handoff")
        }
    }

    private func quarantine(_ directory: URL, reason: String) throws -> Outcome {
        try dependencies.quarantine(directory, reason)
        return .quarantined(reason)
    }

    private func isRegularFile(_ url: URL) -> Bool {
        guard (try? fileManager.destinationOfSymbolicLink(atPath: url.path)) == nil else { return false }
        return (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
    }

    private func safeFileName(_ name: String) -> Bool {
        !name.isEmpty && name != "." && name != ".." && !name.contains("/") && !name.contains("\\") && URL(fileURLWithPath: name).lastPathComponent == name
    }
}
