import XCTest
@testable import Provika

@MainActor
final class ActiveAppPhysicalCaptureControlTests: XCTestCase {
    func testPrimaryEndedCapturesOnePhoto() {
        var photos = 0
        let control = make(behavior: .photo, photo: { photos += 1 })
        control.receive(.ended)
        XCTAssertEqual(photos, 1)
    }

    func testPrimaryEndedStartsAndStopsVideo() {
        var starts = 0, stops = 0
        let control = make(start: { starts += 1 }, stop: { stops += 1 })
        control.receive(.ended)
        control.receive(.began)
        control.receive(.ended)
        XCTAssertEqual(starts, 1)
        XCTAssertEqual(stops, 1)
    }

    func testBeganAndCancelledDoNotCapture() {
        var photos = 0
        let control = make(behavior: .photo, photo: { photos += 1 })
        control.receive(.began)
        control.receive(.cancelled)
        XCTAssertEqual(photos, 0)
    }

    func testRapidAndDuplicateEndedAreSerialized() {
        var photos = 0
        let control = make(behavior: .photo, photo: { photos += 1 })
        control.receive(.ended)
        control.receive(.ended)
        XCTAssertEqual(photos, 1)
    }

    func testBusyStatesDoNotDuplicateMedia() {
        var photos = 0
        let control = ActiveAppPhysicalCaptureControl(
            primaryBehavior: .photo,
            isBusy: { true },
            capturePhoto: { photos += 1 }, startVideo: {}, stopVideo: {}
        )
        control.receive(.ended)
        XCTAssertEqual(photos, 0)
    }

    func testBackgroundAndInterruption() {
        var stops = 0
        let control = make(start: {}, stop: { stops += 1 })
        control.receive(.ended)
        control.applicationDidEnterBackground()
        control.captureSessionWasInterrupted()
        control.captureSessionInterruptionEnded()
        XCTAssertEqual(stops, 1)
    }

    func testUnsupportedDevicePreservesOnScreenCapture() {
        var photos = 0
        let control = ActiveAppPhysicalCaptureControl(
            primaryBehavior: .photo,
            physicalPrimaryAvailable: { false },
            capturePhoto: { photos += 1 }, startVideo: {}, stopVideo: {}
        )
        control.receive(.ended)
        control.performOnScreenPhoto()
        XCTAssertEqual(photos, 1)
    }

    func testSourceDoesNotAffectValidity() {
        var physical = 0, onScreen = 0
        let physicalControl = make(behavior: .photo, photo: { physical += 1 })
        let screenControl = make(behavior: .photo, photo: { onScreen += 1 })
        physicalControl.receive(.ended)
        screenControl.performOnScreenPhoto()
        XCTAssertEqual(physical, onScreen)
    }

    private func make(
        behavior: ActiveAppPhysicalCaptureControl.PrimaryBehavior = .videoToggle,
        photo: @escaping () -> Void = {},
        start: @escaping () -> Void = {},
        stop: @escaping () -> Void = {}
    ) -> ActiveAppPhysicalCaptureControl {
        ActiveAppPhysicalCaptureControl(
            primaryBehavior: behavior,
            capturePhoto: photo,
            startVideo: start,
            stopVideo: stop
        )
    }
}
