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
        var verify: (URL, LockedCaptureHandoff) async -> Bool? = { _, _ in nil }
        var persist: (URL, LockedCaptureHandoff) async throws -> Void = { _, _ in }
        var quarantine: (URL, String) throws -> Void = { _, _ in }
    }

    private let fileManager: FileManager
    private let maximumBytes: Int
    private let dependencies: Dependencies
    // Process-local idempotent replay fence; durable persistence remains the
    // parent pipeline's authority for cross-launch de-duplication.
    private var importedIDs = Set<UUID>()
    private var observationTask: Task<Void, Never>?
    // 관찰 루프와 재시도가 같은 세션을 동시에 처리해 두 번 봉인하지 않도록 막는다.
    private var sessionsInProgress = Set<URL>()

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
            await self.importAll(from: manager)
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

    /// 보호 데이터가 잠겨 있어 미뤄진 촬영분을 다시 시도한다.
    func retryPendingImports() {
        guard observationTask != nil else { return }
        let manager = LockedCameraCaptureManager.shared
        Task { [weak self] in
            await self?.importAll(from: manager)
        }
    }

    private func importAll(from manager: LockedCameraCaptureManager) async {
        for url in manager.sessionContentURLs {
            _ = await importSessionContent(at: url) {
                try await manager.invalidateSessionContent(at: url)
            }
        }
    }

    /// 한 세션에서 여러 번 촬영했을 수 있으므로 대기 중인 인계분을 모두 처리한다.
    /// 세션 콘텐츠는 전부 봉인된 뒤에만 무효화한다. 하나라도 남아 있으면 지우지 않는다.
    func importSessionContent(
        at sessionContentURL: URL,
        invalidateSessionContent: () async throws -> Void = {}
    ) async -> Outcome {
        guard dependencies.protectedDataAvailable() else {
            return .pending(LockedCaptureParentImportPolicy.protectedDataUnavailable)
        }
        guard sessionsInProgress.insert(sessionContentURL).inserted else {
            return .pending("import in progress")
        }
        defer { sessionsInProgress.remove(sessionContentURL) }
        do {
            let pendingDirectories = try fileManager.contentsOfDirectory(
                at: sessionContentURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ).filter { $0.lastPathComponent.hasPrefix("pending-") }
            guard !pendingDirectories.isEmpty else { return .pending("no pending handoff") }

            var outcomes: [Outcome] = []
            var unresolved = false
            for directory in pendingDirectories.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                let outcome = await importHandoff(directory)
                outcomes.append(outcome)
                // 격리로 옮겨진 인계분은 세션에 더 남아 있지 않으므로 무효화를 막지 않는다.
                if !outcome.isDurable, fileManager.fileExists(atPath: directory.path) {
                    unresolved = true
                }
            }
            let reported = outcomes.first(where: { !$0.isDurable }) ?? outcomes[0]
            guard !unresolved else { return reported }
            do {
                try await invalidateSessionContent()
            } catch {
                // 봉인은 끝났다. 무효화는 다음 실행에서 중복 검사를 거쳐 다시 시도된다.
            }
            return reported
        } catch {
            return .quarantined("handoff enumeration failed")
        }
    }

    private func importHandoff(_ directory: URL) async -> Outcome {
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
                return .duplicate(handoff.handoffID)
            }
            guard let independentlyVerified = await dependencies.verify(mediaURL, handoff) else {
                return .pending("parent verifier unavailable")
            }
            guard independentlyVerified else { return try quarantine(directory, reason: "verify rejected handoff") }
            do {
                try await dependencies.persist(mediaURL, handoff)
            } catch {
                // 봉인 실패는 미디어 결함이 아니다(키 접근·저장 공간 등). 원본을 남겨 두고 다음에 다시 시도한다.
                return .pending("persist failed")
            }
            importedIDs.insert(handoff.handoffID)
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

private extension LockedCaptureImportCoordinator.Outcome {
    /// 원본을 지워도 되는 결과인지.
    var isDurable: Bool {
        switch self {
        case .imported, .duplicate: true
        case .pending, .quarantined: false
        }
    }
}
