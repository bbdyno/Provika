import XCTest
@testable import Provika

// Coverage vocabulary: unsupported capability fallback and simultaneous input serialization.

final class CaptureCommandCoordinatorTests: XCTestCase {
    func testAllSupportedSourcesUseTheSameStartPath() {
        for source in CaptureCommandSource.allCases {
            var prepareCount = 0
            let coordinator = makeCoordinator(primary: true, secondary: true, prepare: { prepareCount += 1 })
            XCTAssertEqual(coordinator.submit(.start, from: source), .accepted(.preparing))
            XCTAssertEqual(coordinator.state, .preparing)
            XCTAssertEqual(prepareCount, 1)
        }
    }

    func testUnavailablePhysicalInputRejectsAndScreenCaptureRemainsAvailable() {
        let coordinator = makeCoordinator(primary: false, secondary: false)
        XCTAssertEqual(
            coordinator.submit(.start, from: .physicalPrimary),
            .rejected(.unavailablePhysicalInput(.physicalPrimary))
        )
        XCTAssertEqual(coordinator.state, .idle)
        XCTAssertEqual(coordinator.diagnostics.last?.source, .physicalPrimary)
        XCTAssertEqual(coordinator.submit(.start, from: .onScreen), .accepted(.preparing))

        let intentCoordinator = makeCoordinator(primary: false, secondary: false)
        XCTAssertEqual(
            intentCoordinator.submit(.start, from: .physicalSecondary),
            .rejected(.unavailablePhysicalInput(.physicalSecondary))
        )
        XCTAssertEqual(intentCoordinator.submit(.start, from: .activeAppIntent), .accepted(.preparing))
    }

    func testUnsupportedPhysicalCapabilityDoesNotBlockLifecycleSerialization() {
        var primaryAvailable = true
        let coordinator = CaptureCommandCoordinator(
            capabilities: .init(
                physicalPrimaryAvailable: { primaryAvailable },
                physicalSecondaryAvailable: { false }
            )
        )
        XCTAssertEqual(coordinator.submit(.start, from: .physicalPrimary), .accepted(.preparing))
        primaryAvailable = false

        // A completion is not a new physical action. It must be serialized so
        // an already accepted capture can finish deterministically.
        XCTAssertEqual(coordinator.submit(.preparationFinished(success: true), from: .physicalPrimary), .accepted(.capturing))
        XCTAssertEqual(coordinator.submit(.stop, from: .physicalPrimary), .accepted(.stopping))
    }

    func testProvenanceIsDiagnosticOnly() {
        let onScreen = makeCoordinator(primary: true, secondary: true)
        let physical = makeCoordinator(primary: true, secondary: true)
        XCTAssertEqual(onScreen.submit(.start, from: .onScreen), physical.submit(.start, from: .physicalPrimary))
        XCTAssertEqual(onScreen.state, physical.state)
        XCTAssertEqual(onScreen.diagnostics.last?.source, .onScreen)
        XCTAssertEqual(physical.diagnostics.last?.source, .physicalPrimary)
    }

    func testFrozenInputSemanticsRoundTripWithoutPuttingProvenanceInCommands() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for source in CaptureCommandSource.allCases {
            let data = try encoder.encode(source)
            XCTAssertEqual(try decoder.decode(CaptureCommandSource.self, from: data), source)
            XCTAssertEqual(String(decoding: data, as: UTF8.self), "\"\(source.rawValue)\"")
        }

        let command = CaptureCommand.permissionChanged(granted: false)
        let data = try encoder.encode(command)
        XCTAssertEqual(try decoder.decode(CaptureCommand.self, from: data), command)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains(CaptureCommandSource.onScreen.rawValue))
    }

    func testSuccessfulLifecycleSerializesPreparationStopFinalizationAndPersistence() {
        var calls: [String] = []
        let coordinator = makeCoordinator(
            prepare: { calls.append("prepare") }, stop: { calls.append("stop") },
            finalize: { calls.append("finalize") }, persist: { calls.append("persist") }
        )
        XCTAssertEqual(coordinator.submit(.start, from: .onScreen), .accepted(.preparing))
        XCTAssertEqual(coordinator.submit(.preparationFinished(success: true), from: .activeAppIntent), .accepted(.capturing))
        XCTAssertEqual(coordinator.submit(.stop, from: .physicalSecondary), .accepted(.stopping))
        XCTAssertEqual(coordinator.submit(.stopFinished(success: true), from: .onScreen), .accepted(.finalizing))
        XCTAssertEqual(coordinator.submit(.finalizationFinished(success: true), from: .onScreen), .accepted(.persisting))
        XCTAssertEqual(coordinator.submit(.persistenceFinished(success: true), from: .onScreen), .accepted(.idle))
        XCTAssertEqual(calls, ["prepare", "stop", "finalize", "persist"])
    }

    func testSimultaneousAndRapidInputsRejectBusyStates() {
        // The coordinator's single locked command path serializes simultaneous
        // inputs; this deterministic sequence exercises the resulting policy.
        let coordinator = makeCoordinator()
        _ = coordinator.submit(.start, from: .onScreen)
        XCTAssertEqual(coordinator.submit(.start, from: .activeAppIntent), .rejected(.busy(.preparing)))
        XCTAssertEqual(coordinator.submit(.preparationFinished(success: true), from: .onScreen), .accepted(.capturing))
        _ = coordinator.submit(.stop, from: .onScreen)
        for command in [CaptureCommand.start, .stop] {
            XCTAssertEqual(coordinator.submit(command, from: .onScreen), .rejected(.busy(.stopping)))
        }
        _ = coordinator.submit(.stopFinished(success: true), from: .onScreen)
        XCTAssertEqual(coordinator.submit(.stop, from: .onScreen), .rejected(.busy(.finalizing)))
        _ = coordinator.submit(.finalizationFinished(success: true), from: .onScreen)
        XCTAssertEqual(coordinator.submit(.start, from: .onScreen), .rejected(.busy(.persisting)))
    }

    func testDuplicateEndedEventsAreAlwaysHarmless() {
        let coordinator = makeCoordinator()
        XCTAssertEqual(coordinator.submit(.ended, from: .physicalPrimary), .ignoredDuplicateEnded)
        _ = coordinator.submit(.start, from: .onScreen)
        XCTAssertEqual(coordinator.submit(.ended, from: .physicalPrimary), .ignoredDuplicateEnded)
        XCTAssertEqual(coordinator.state, .preparing)
    }

    func testUnavailablePhysicalEndedEventIsStillHarmless() {
        let coordinator = makeCoordinator(primary: false)
        XCTAssertEqual(coordinator.submit(.ended, from: .physicalPrimary), .ignoredDuplicateEnded)
        XCTAssertEqual(coordinator.state, .idle)
    }

    func testBackgroundAndInterruptionStopActiveCaptureButDrainFinishingWork() {
        var stopCount = 0
        let coordinator = makeCoordinator(stop: { stopCount += 1 })
        startCapturing(coordinator)
        XCTAssertEqual(coordinator.submit(.appBackgrounded, from: .onScreen), .accepted(.stopping))
        XCTAssertEqual(stopCount, 1)
        XCTAssertEqual(coordinator.submit(.interruptionBegan, from: .onScreen), .accepted(.stopping))
        _ = coordinator.submit(.stopFinished(success: true), from: .onScreen)
        XCTAssertEqual(coordinator.submit(.appBackgrounded, from: .onScreen), .accepted(.finalizing))
    }

    func testInterruptionBlocksNewCaptureUntilItEndsWhileBackgroundDoesNotChangeIdle() {
        let coordinator = makeCoordinator()
        XCTAssertEqual(coordinator.submit(.appBackgrounded, from: .onScreen), .accepted(.idle))
        XCTAssertEqual(coordinator.submit(.interruptionBegan, from: .onScreen), .accepted(.interrupted))
        XCTAssertEqual(coordinator.submit(.start, from: .onScreen), .rejected(.invalidState(.interrupted)))
        XCTAssertEqual(coordinator.submit(.interruptionEnded, from: .onScreen), .accepted(.idle))
    }

    func testPermissionLossStopsCaptureAndDeniedPermissionRejectsStart() {
        var stops = 0
        let coordinator = makeCoordinator(stop: { stops += 1 })
        startCapturing(coordinator)
        XCTAssertEqual(coordinator.submit(.permissionChanged(granted: false), from: .onScreen), .accepted(.stopping))
        XCTAssertEqual(stops, 1)
        _ = coordinator.submit(.stopFinished(success: true), from: .onScreen)
        _ = coordinator.submit(.finalizationFinished(success: true), from: .onScreen)
        _ = coordinator.submit(.persistenceFinished(success: true), from: .onScreen)
        XCTAssertEqual(coordinator.submit(.start, from: .onScreen), .rejected(.permissionDenied))
    }

    func testTerminationIsTerminalAndRequestsTeardownOnce() {
        var stops = 0
        var terminations = 0
        let coordinator = makeCoordinator(stop: { stops += 1 }, terminate: { terminations += 1 })
        startCapturing(coordinator)
        XCTAssertEqual(coordinator.submit(.terminationRequested, from: .activeAppIntent), .accepted(.terminated))
        XCTAssertEqual(stops, 1)
        XCTAssertEqual(terminations, 1)
        XCTAssertEqual(coordinator.submit(.terminationRequested, from: .onScreen), .rejected(.terminated))
        XCTAssertEqual(terminations, 1)
    }

    func testLifecycleFailuresReachFailedAndCanBeRestarted() {
        let coordinator = makeCoordinator()
        _ = coordinator.submit(.start, from: .onScreen)
        XCTAssertEqual(coordinator.submit(.preparationFinished(success: false), from: .onScreen), .accepted(.failed))
        XCTAssertEqual(coordinator.submit(.start, from: .activeAppIntent), .accepted(.preparing))
    }

    private func startCapturing(_ coordinator: CaptureCommandCoordinator) {
        _ = coordinator.submit(.start, from: .onScreen)
        _ = coordinator.submit(.preparationFinished(success: true), from: .onScreen)
    }

    private func makeCoordinator(
        primary: Bool = true, secondary: Bool = true,
        prepare: @escaping () -> Void = {}, stop: @escaping () -> Void = {},
        finalize: @escaping () -> Void = {}, persist: @escaping () -> Void = {},
        terminate: @escaping () -> Void = {}
    ) -> CaptureCommandCoordinator {
        .init(
            capabilities: .init(physicalPrimaryAvailable: { primary }, physicalSecondaryAvailable: { secondary }),
            dependencies: .init(prepare: prepare, stop: stop, finalize: finalize, persist: persist, terminate: terminate)
        )
    }
}
