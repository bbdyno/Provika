import Foundation
import Observation
import SwiftData

/// App-facing boundary for the photo-evidence vertical slice.
///
/// The frozen pipeline remains the authority for package finalization and
/// verification. This type only coordinates capture, user-visible state, and
/// persistence of packages that that pipeline has already approved.
@MainActor
@Observable
final class PhotoEvidenceVerticalSliceCoordinator {
    enum State: Equatable {
        case idle
        case capturing
        case succeeded
        case failed
    }

    typealias Completion = @MainActor (PhotoEvidenceCapturePipelineResultV2) -> Void
    typealias Capture = (@escaping Completion) -> Void
    typealias Persist = (PhotoEvidenceClaimV2, URL) throws -> Void

    private let capture: Capture
    private let persist: Persist
    private var workflow = CaptureWorkflowStateMachine()
    private var activeOperation: EvidenceWorkflowOperationID?

    private(set) var state: State = .idle

    init(capture: @escaping Capture, persist: @escaping Persist) {
        self.capture = capture
        self.persist = persist
    }

    convenience init(captureService: CaptureService, modelContext: ModelContext, packageRoot: URL) {
        let pipeline = PhotoEvidenceCapturePipelineV2(rootDirectory: packageRoot)
        self.init(
            capture: { completion in
                captureService.capturePhotoEvidence(using: pipeline) { outcome in
                    Task { @MainActor in
                        completion(outcome)
                    }
                }
            },
            persist: { claim, packageDirectory in
                let record = EvidenceRecord(
                    id: "photo-package:\(claim.packageID.uuidString.lowercased())",
                    schemaVersion: 2,
                    capturedAt: Self.captureDate(from: claim),
                    evidenceKindRawValue: "photo_evidence",
                    verificationStateRawValue: EvidenceVerificationState.verified.rawValue,
                    packagePath: packageDirectory.path,
                    contentHash: claim.media.sha256,
                    startLatitude: claim.location?.lat,
                    startLongitude: claim.location?.lng
                )
                modelContext.insert(record)
                do {
                    try modelContext.save()
                } catch {
                    modelContext.delete(record)
                    throw error
                }
            }
        )
    }

    func capturePhotoEvidence() {
        guard state != .capturing else { return }
        if state != .idle {
            acknowledgeFeedback()
        }
        let operation = EvidenceWorkflowOperationID(rawValue: UUID().uuidString.lowercased())
        guard case .accepted = workflow.transition(.start(operation)) else { return }
        activeOperation = operation
        state = .capturing

        capture { [weak self] outcome in
            self?.complete(outcome, operation: operation)
        }
    }

    private func complete(_ outcome: PhotoEvidenceCapturePipelineResultV2, operation: EvidenceWorkflowOperationID) {
        guard activeOperation == operation else { return }
        defer { activeOperation = nil }

        switch outcome {
        case let .success(packageDirectory, claim):
            do {
                try persist(claim, packageDirectory)
                guard case .accepted = workflow.transition(.complete(operation)) else {
                    state = .failed
                    return
                }
                state = .succeeded
            } catch {
                _ = workflow.transition(.fail(operation))
                state = .failed
            }
        case .failure:
            _ = workflow.transition(.fail(operation))
            state = .failed
        }
    }

    func acknowledgeFeedback() {
        guard state != .capturing else { return }
        _ = workflow.transition(.reset)
        state = .idle
    }

    private static func captureDate(from claim: PhotoEvidenceClaimV2) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: claim.capture.deviceTime) ?? .now
    }
}
