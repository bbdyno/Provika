import Foundation

/// The filesystem surface used by `EvidenceDataSafety`.  Keeping it small makes
/// retention and deletion decisions deterministic and independently testable.
protocol EvidenceDataSafetyFileSystem {
    /// Unlike `fileExists`, this reports the directory entry itself.  In
    /// particular, a dangling symbolic link still exists and must be rejected.
    func itemExists(at url: URL) -> Bool
    func fileExists(at url: URL) -> Bool
    func isDirectory(at url: URL) -> Bool
    func isSymbolicLink(at url: URL) throws -> Bool
    func contentsOfDirectory(at url: URL) throws -> [URL]
    func removeItem(at url: URL) throws
    func data(at url: URL) throws -> Data
}

extension FileManager: EvidenceDataSafetyFileSystem {
    func itemExists(at url: URL) -> Bool {
        (try? attributesOfItem(atPath: url.path)) != nil
    }

    func fileExists(at url: URL) -> Bool { fileExists(atPath: url.path) }

    func isDirectory(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard fileExists(atPath: url.path, isDirectory: &isDirectory) else { return false }
        return isDirectory.boolValue
    }

    func isSymbolicLink(at url: URL) throws -> Bool {
        let attributes = try attributesOfItem(atPath: url.path)
        return attributes[.type] as? FileAttributeType == .typeSymbolicLink
    }

    func contentsOfDirectory(at url: URL) throws -> [URL] {
        try contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
    }

    func data(at url: URL) throws -> Data { try Data(contentsOf: url) }
}

/// A deliberately narrow boundary for retention and destructive local-data work.
/// It neither knows nor imports SwiftData; callers may optionally carry a row ID.
struct EvidenceDataSafety {
    enum ArtifactFamily: String, CaseIterable, Hashable, Sendable {
        case video
        case photo
        case metadata
        case thumbnail
        case evidencePackage
        case export
        case staging
        case diagnostic
    }

    /// A complete manifest can include temporary and final zip artifacts through
    /// the `export` or `evidencePackage` families; both remain ordinary owned
    /// files subject to the same bounded deletion rules.

    struct Artifact: Equatable {
        let family: ArtifactFamily
        let url: URL?

        init(family: ArtifactFamily, url: URL?) {
            self.family = family
            self.url = url
        }
    }

    /// Every known family must be represented once. `nil` means that family was
    /// not created for this evidence item, rather than silently being omitted.
    struct DeletionManifest: Equatable {
        let root: URL
        let artifacts: [Artifact]
        let persistenceRowIdentifier: String?

        init(root: URL, artifacts: [Artifact], persistenceRowIdentifier: String? = nil) throws {
            guard artifacts.count == ArtifactFamily.allCases.count,
                  Set(artifacts.map(\.family)) == Set(ArtifactFamily.allCases),
                  Set(artifacts.compactMap { $0.url?.standardizedFileURL.path }).count == artifacts.compactMap({ $0.url }).count else {
                throw Error.incompleteManifest
            }
            self.root = root
            self.artifacts = artifacts
            self.persistenceRowIdentifier = persistenceRowIdentifier
        }

        static func complete(root: URL, locations: [ArtifactFamily: URL], persistenceRowIdentifier: String? = nil) throws -> DeletionManifest {
            guard locations.count <= ArtifactFamily.allCases.count else {
                throw Error.incompleteManifest
            }
            return try DeletionManifest(
                root: root,
                artifacts: ArtifactFamily.allCases.map { Artifact(family: $0, url: locations[$0]) },
                persistenceRowIdentifier: persistenceRowIdentifier
            )
        }
    }

    struct RetentionPolicy: Equatable, Sendable {
        let maximumAge: TimeInterval
        init(maximumAge: TimeInterval) { self.maximumAge = maximumAge }
    }

    enum RetentionDecision: Equatable {
        case retain
        case delete
        case rejectFutureTimestamp
    }

    struct DeletionReport: Equatable {
        let deletedFamilies: Set<ArtifactFamily>
        let alreadyAbsentFamilies: Set<ArtifactFamily>
        let failures: [ArtifactFamily: Diagnostic]

        var isComplete: Bool { failures.isEmpty }
    }

    enum StagingRecovery: Equatable {
        case removed
        case alreadyAbsent
        case failed(Diagnostic)
    }

    struct Diagnostic: Equatable, Sendable {
        let code: Code
        let family: ArtifactFamily?

        enum Code: String, Sendable {
            case invalidRoot, outsideRoot, traversal, symbolicLink, invalidStagingOwnership
            case filesystemFailure, futureTimestamp
        }

        /// Redacted by design: contains no path, filename, row ID, or underlying error.
        init(code: Code, family: ArtifactFamily? = nil) {
            self.code = code
            self.family = family
        }
    }

    enum Error: Swift.Error, Equatable {
        case incompleteManifest
        case unsafePath(Diagnostic)
    }

    typealias Clock = () -> Date

    private let fileSystem: EvidenceDataSafetyFileSystem
    private let clock: Clock

    init(fileSystem: EvidenceDataSafetyFileSystem = FileManager.default, clock: @escaping Clock = Date.init) {
        self.fileSystem = fileSystem
        self.clock = clock
    }

    func retentionDecision(createdAt: Date, policy: RetentionPolicy) -> RetentionDecision {
        let now = clock()
        guard createdAt <= now else { return .rejectFutureTimestamp }
        return now.timeIntervalSince(createdAt) >= policy.maximumAge ? .delete : .retain
    }

    func delete(_ manifest: DeletionManifest) throws -> DeletionReport {
        try validateRoot(manifest.root)
        var deleted = Set<ArtifactFamily>()
        var absent = Set<ArtifactFamily>()
        var failures: [ArtifactFamily: Diagnostic] = [:]

        for artifact in manifest.artifacts {
            guard let url = artifact.url else { continue }
            try validate(url, beneath: manifest.root)
            guard fileSystem.itemExists(at: url) else {
                absent.insert(artifact.family)
                continue
            }
            do {
                try removeTree(at: url, root: manifest.root)
                deleted.insert(artifact.family)
            } catch let error as Error {
                // A traversal or symlink found while walking a directory is a
                // boundary violation, not a partial deletion result.
                throw error
            } catch {
                failures[artifact.family] = Diagnostic(code: .filesystemFailure, family: artifact.family)
            }
        }
        return DeletionReport(deletedFamilies: deleted, alreadyAbsentFamilies: absent, failures: failures)
    }

    /// Performs interruption recovery by deleting only a direct child of the
    /// caller-owned staging root, after a non-symlink ownership marker verifies
    /// the supplied opaque owner token.
    func recoverInterruptedStaging(stagingDirectory: URL, stagingRoot: URL, ownerToken: String) throws -> StagingRecovery {
        try validateRoot(stagingRoot)
        try validate(stagingDirectory, beneath: stagingRoot)
        guard stagingDirectory.deletingLastPathComponent().standardizedFileURL == stagingRoot.standardizedFileURL,
              stagingDirectory.lastPathComponent == ownerToken,
              !ownerToken.isEmpty else {
            throw Error.unsafePath(Diagnostic(code: .invalidStagingOwnership))
        }
        guard fileSystem.itemExists(at: stagingDirectory) else { return .alreadyAbsent }
        guard fileSystem.isDirectory(at: stagingDirectory) else {
            throw Error.unsafePath(Diagnostic(code: .invalidStagingOwnership))
        }
        let marker = stagingDirectory.appendingPathComponent(".provika-staging-owner")
        try validate(marker, beneath: stagingRoot)
        guard fileSystem.itemExists(at: marker),
              String(data: try fileSystem.data(at: marker), encoding: .utf8) == ownerToken else {
            throw Error.unsafePath(Diagnostic(code: .invalidStagingOwnership))
        }
        do {
            try removeTree(at: stagingDirectory, root: stagingRoot)
            return .removed
        } catch let error as Error {
            throw error
        } catch {
            return .failed(Diagnostic(code: .filesystemFailure))
        }
    }

    private func validateRoot(_ root: URL) throws {
        guard root.isFileURL, !containsTraversal(root), fileSystem.itemExists(at: root), fileSystem.isDirectory(at: root) else {
            throw Error.unsafePath(Diagnostic(code: .invalidRoot))
        }
        try rejectSymbolicLink(at: root)
    }

    private func validate(_ url: URL, beneath root: URL) throws {
        guard url.isFileURL else { throw Error.unsafePath(Diagnostic(code: .outsideRoot)) }
        guard !containsTraversal(url) else { throw Error.unsafePath(Diagnostic(code: .traversal)) }
        let canonicalRoot = root.standardizedFileURL
        let canonicalURL = url.standardizedFileURL
        guard canonicalURL.pathComponents.starts(with: canonicalRoot.pathComponents), canonicalURL != canonicalRoot else {
            throw Error.unsafePath(Diagnostic(code: .outsideRoot))
        }
        var current = canonicalRoot
        for component in canonicalURL.pathComponents.dropFirst(canonicalRoot.pathComponents.count) {
            current.appendPathComponent(component)
            if fileSystem.itemExists(at: current) { try rejectSymbolicLink(at: current) }
        }
    }

    private func removeTree(at url: URL, root: URL) throws {
        try validate(url, beneath: root)
        if fileSystem.isDirectory(at: url) {
            for child in try fileSystem.contentsOfDirectory(at: url) {
                try removeTree(at: child, root: root)
            }
        }
        try fileSystem.removeItem(at: url)
    }

    private func containsTraversal(_ url: URL) -> Bool {
        url.path.split(separator: "/", omittingEmptySubsequences: true).contains("..")
    }

    private func rejectSymbolicLink(at url: URL) throws {
        do {
            if try fileSystem.isSymbolicLink(at: url) {
                throw Error.unsafePath(Diagnostic(code: .symbolicLink))
            }
        } catch let error as Error {
            throw error
        } catch {
            throw Error.unsafePath(Diagnostic(code: .filesystemFailure))
        }
    }
}
