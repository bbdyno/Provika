import XCTest
@testable import Provika

final class EvidenceWorkflowStateMachinesTests: XCTestCase {
    private let first: EvidenceWorkflowOperationID = "first"
    private let second: EvidenceWorkflowOperationID = "second"

    func testCaptureTransitionTable() {
        assertTransitionTable(
            make: { CaptureWorkflowStateMachine(maximumFailures: 2) },
            start: CaptureWorkflowStateMachine.Event.start,
            complete: CaptureWorkflowStateMachine.Event.complete,
            fail: CaptureWorkflowStateMachine.Event.fail,
            cancel: CaptureWorkflowStateMachine.Event.cancel,
            interrupt: CaptureWorkflowStateMachine.Event.interrupt,
            recover: CaptureWorkflowStateMachine.Event.recover,
            retry: CaptureWorkflowStateMachine.Event.retry,
            reset: .reset
        )
    }

    func testVerificationTransitionTable() {
        assertTransitionTable(
            make: { VerificationWorkflowStateMachine(maximumFailures: 2) },
            start: VerificationWorkflowStateMachine.Event.start,
            complete: VerificationWorkflowStateMachine.Event.complete,
            fail: VerificationWorkflowStateMachine.Event.fail,
            cancel: VerificationWorkflowStateMachine.Event.cancel,
            interrupt: VerificationWorkflowStateMachine.Event.interrupt,
            recover: VerificationWorkflowStateMachine.Event.recover,
            retry: VerificationWorkflowStateMachine.Event.retry,
            reset: .reset
        )
    }

    func testExportTransitionTable() {
        assertTransitionTable(
            make: { ExportWorkflowStateMachine(maximumFailures: 2) },
            start: ExportWorkflowStateMachine.Event.start,
            complete: ExportWorkflowStateMachine.Event.complete,
            fail: ExportWorkflowStateMachine.Event.fail,
            cancel: ExportWorkflowStateMachine.Event.cancel,
            interrupt: ExportWorkflowStateMachine.Event.interrupt,
            recover: ExportWorkflowStateMachine.Event.recover,
            retry: ExportWorkflowStateMachine.Event.retry,
            reset: .reset
        )
    }

    func testFailuresAreBoundedAndResetRestoresAvailability() {
        var machine = CaptureWorkflowStateMachine(maximumFailures: 2)
        XCTAssertEqual(machine.transition(.start(first)), .accepted(.capturing(operation: first, failures: 0)))
        XCTAssertEqual(machine.transition(.fail(first)), .accepted(.failed(failures: 1)))
        XCTAssertEqual(machine.transition(.retry(second)), .accepted(.capturing(operation: second, failures: 1)))
        XCTAssertEqual(machine.transition(.fail(second)), .accepted(.failed(failures: 2)))

        let exhausted = machine.state
        XCTAssertEqual(machine.transition(.retry(first)), .rejected(.retryLimitReached))
        XCTAssertEqual(machine.state, exhausted)
        XCTAssertEqual(machine.transition(.reset), .accepted(.idle))
        XCTAssertEqual(machine.transition(.start(first)), .accepted(.capturing(operation: first, failures: 0)))
    }

    func testStaleOperationEventsAreRejectedWithoutMutation() {
        var capture = CaptureWorkflowStateMachine()
        _ = capture.transition(.start(first))
        let captureState = capture.state
        XCTAssertEqual(capture.transition(.complete(second)), .rejected(.staleOperation))
        XCTAssertEqual(capture.state, captureState)

        var verification = VerificationWorkflowStateMachine()
        _ = verification.transition(.start(first))
        let verificationState = verification.state
        XCTAssertEqual(verification.transition(.fail(second)), .rejected(.staleOperation))
        XCTAssertEqual(verification.state, verificationState)

        var export = ExportWorkflowStateMachine()
        _ = export.transition(.start(first))
        _ = export.transition(.interrupt(first))
        let exportState = export.state
        XCTAssertEqual(export.transition(.recover(second)), .rejected(.staleOperation))
        XCTAssertEqual(export.state, exportState)
    }

    private func assertTransitionTable<Machine: EvidenceWorkflowStateMachine>(
        make: () -> Machine,
        start: @escaping (EvidenceWorkflowOperationID) -> Machine.Event,
        complete: @escaping (EvidenceWorkflowOperationID) -> Machine.Event,
        fail: @escaping (EvidenceWorkflowOperationID) -> Machine.Event,
        cancel: @escaping (EvidenceWorkflowOperationID) -> Machine.Event,
        interrupt: @escaping (EvidenceWorkflowOperationID) -> Machine.Event,
        recover: @escaping (EvidenceWorkflowOperationID) -> Machine.Event,
        retry: @escaping (EvidenceWorkflowOperationID) -> Machine.Event,
        reset: Machine.Event
    ) {
        let events: [(String, Machine.Event)] = [
            ("start", start(first)), ("complete current", complete(first)), ("complete stale", complete(second)),
            ("fail current", fail(first)), ("fail stale", fail(second)),
            ("cancel current", cancel(first)), ("cancel stale", cancel(second)),
            ("interrupt current", interrupt(first)), ("interrupt stale", interrupt(second)),
            ("recover current", recover(first)), ("recover stale", recover(second)),
            ("retry", retry(second)), ("reset", reset)
        ]

        for (name, setup, accepted) in transitionRows(make: make, start: start, complete: complete, fail: fail, cancel: cancel, interrupt: interrupt, recover: recover, retry: retry) {
            for (eventName, event) in events {
                var machine = make()
                setup(&machine)
                let before = machine.state
                let result = machine.transition(event)
                if accepted.contains(eventName) {
                    if case .accepted = result { } else { XCTFail("\(name): \(eventName) should be accepted") }
                } else {
                    if case .rejected = result { } else { XCTFail("\(name): \(eventName) should be rejected") }
                    XCTAssertEqual(machine.state, before, "\(name): rejected \(eventName) mutated state")
                }
            }
        }
    }

    private func transitionRows<Machine: EvidenceWorkflowStateMachine>(
        make: () -> Machine,
        start: @escaping (EvidenceWorkflowOperationID) -> Machine.Event,
        complete: @escaping (EvidenceWorkflowOperationID) -> Machine.Event,
        fail: @escaping (EvidenceWorkflowOperationID) -> Machine.Event,
        cancel: @escaping (EvidenceWorkflowOperationID) -> Machine.Event,
        interrupt: @escaping (EvidenceWorkflowOperationID) -> Machine.Event,
        recover: @escaping (EvidenceWorkflowOperationID) -> Machine.Event,
        retry: @escaping (EvidenceWorkflowOperationID) -> Machine.Event
    ) -> [(String, (inout Machine) -> Void, Set<String>)] {
        [
            ("idle", { _ in }, ["start"]),
            ("active", { _ = $0.transition(start(self.first)) }, ["complete current", "fail current", "cancel current", "interrupt current"]),
            ("interrupted", { _ = $0.transition(start(self.first)); _ = $0.transition(interrupt(self.first)) }, ["recover current"]),
            ("cancelled", { _ = $0.transition(start(self.first)); _ = $0.transition(cancel(self.first)) }, ["retry", "reset"]),
            ("failed", { _ = $0.transition(start(self.first)); _ = $0.transition(fail(self.first)) }, ["retry", "reset"]),
            ("completed", { _ = $0.transition(start(self.first)); _ = $0.transition(complete(self.first)) }, ["reset"])
        ]
    }
}
