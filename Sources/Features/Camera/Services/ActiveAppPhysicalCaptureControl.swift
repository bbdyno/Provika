import AVFoundation
import AVKit
import UIKit

/// Testable adapter from active-app hardware capture events to the same serialized
/// command path used by on-screen controls. Capture origin is never evidence data.
@MainActor
final class ActiveAppPhysicalCaptureControl {
    enum EventPhase: String { case began, ended, cancelled }
    enum PrimaryBehavior { case photo, videoToggle }

    private static let registry = NSMapTable<AVCaptureSession, ActiveAppPhysicalCaptureControl>(
        keyOptions: .weakMemory,
        valueOptions: .weakMemory
    )

    private let commandCoordinator: CaptureCommandCoordinator
    private let capturePhoto: () -> Void
    private let startVideo: () -> Void
    private let stopVideo: () -> Void
    private let isBusy: () -> Bool
    private(set) var primaryBehavior: PrimaryBehavior
    private var videoCommandActive = false
    private var primaryEndedArmed = true

    init(
        primaryBehavior: PrimaryBehavior = .videoToggle,
        physicalPrimaryAvailable: @escaping @Sendable () -> Bool = { true },
        isBusy: @escaping () -> Bool = { false },
        capturePhoto: @escaping () -> Void,
        startVideo: @escaping () -> Void,
        stopVideo: @escaping () -> Void
    ) {
        self.primaryBehavior = primaryBehavior
        self.isBusy = isBusy
        self.capturePhoto = capturePhoto
        self.startVideo = startVideo
        self.stopVideo = stopVideo
        commandCoordinator = CaptureCommandCoordinator(
            capabilities: .init(physicalPrimaryAvailable: physicalPrimaryAvailable)
        )
    }

    func setPrimaryBehavior(_ behavior: PrimaryBehavior) {
        primaryBehavior = behavior
    }

    func receive(_ phase: EventPhase, primary: Bool = true) {
        guard primary else { return }
        switch phase {
        case .began:
            primaryEndedArmed = true
            return
        case .cancelled:
            primaryEndedArmed = false
            return
        case .ended:
            guard primaryEndedArmed else { return }
            primaryEndedArmed = false
        }
        switch primaryBehavior {
        case .photo:
            performPhoto(from: .physicalPrimary)
        case .videoToggle:
            performVideoToggle(from: .physicalPrimary)
        }
    }

    func performOnScreenPhoto() { performPhoto(from: .onScreen) }
    func performOnScreenVideoToggle() { performVideoToggle(from: .onScreen) }

    func applicationDidEnterBackground() {
        _ = commandCoordinator.submit(.appBackgrounded, from: .onScreen)
        if videoCommandActive {
            stopVideo()
            videoCommandActive = false
            finishStopLifecycle(from: .onScreen)
        }
    }

    func captureSessionWasInterrupted() {
        _ = commandCoordinator.submit(.interruptionBegan, from: .onScreen)
        if videoCommandActive {
            stopVideo()
            videoCommandActive = false
            finishStopLifecycle(from: .onScreen)
        }
    }

    func captureSessionInterruptionEnded() {
        _ = commandCoordinator.submit(.interruptionEnded, from: .onScreen)
    }

    func makeInteraction() -> AVCaptureEventInteraction {
        AVCaptureEventInteraction(primary: { [weak self] event in
            guard let phase = EventPhase(rawValue: String(describing: event.phase)) else { return }
            Task { @MainActor in self?.receive(phase, primary: true) }
        }, secondary: { _ in
            // Secondary is deliberately left to system behavior for this release.
        })
    }

    static func register(_ control: ActiveAppPhysicalCaptureControl, for session: AVCaptureSession) {
        registry.setObject(control, forKey: session)
    }

    static func registered(for session: AVCaptureSession) -> ActiveAppPhysicalCaptureControl? {
        registry.object(forKey: session)
    }

    private func performPhoto(from source: CaptureCommandSource) {
        guard !isBusy() else { return }
        guard case .accepted = commandCoordinator.submit(.start, from: source) else { return }
        capturePhoto()
        _ = commandCoordinator.submit(.preparationFinished(success: true), from: source)
        _ = commandCoordinator.submit(.stop, from: source)
        finishStopLifecycle(from: source)
    }

    private func performVideoToggle(from source: CaptureCommandSource) {
        if videoCommandActive {
            guard case .accepted = commandCoordinator.submit(.stop, from: source) else { return }
            stopVideo()
            videoCommandActive = false
            finishStopLifecycle(from: source)
        } else {
            guard !isBusy() else { return }
            guard case .accepted = commandCoordinator.submit(.start, from: source) else { return }
            startVideo()
            videoCommandActive = true
            _ = commandCoordinator.submit(.preparationFinished(success: true), from: source)
        }
    }

    private func finishStopLifecycle(from source: CaptureCommandSource) {
        _ = commandCoordinator.submit(.stopFinished(success: true), from: source)
        _ = commandCoordinator.submit(.finalizationFinished(success: true), from: source)
        _ = commandCoordinator.submit(.persistenceFinished(success: true), from: source)
    }
}
