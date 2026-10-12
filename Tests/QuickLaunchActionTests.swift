import XCTest
@testable import Provika

final class QuickLaunchActionTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "QuickLaunchActionTests"

    override func setUp() {
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testDefaultKeepsExistingBehaviorOfStartingVideo() {
        XCTAssertEqual(QuickLaunchAction.preferred(in: defaults), .startVideo)
        defaults.set("not-an-action", forKey: QuickLaunchAction.defaultsKey)
        XCTAssertEqual(QuickLaunchAction.preferred(in: defaults), .startVideo)
    }

    func testNamedIntentsIgnoreThePreference() {
        defaults.set(QuickLaunchAction.openCamera.rawValue, forKey: QuickLaunchAction.defaultsKey)
        XCTAssertEqual(QuickLaunchAction.resolve(.startVideo, defaults: defaults), .startVideo)
        XCTAssertEqual(QuickLaunchAction.resolve(.capturePhoto, defaults: defaults), .capturePhoto)
    }

    func testCameraEntryPointFollowsThePreference() {
        for action in QuickLaunchAction.allCases {
            defaults.set(action.rawValue, forKey: QuickLaunchAction.defaultsKey)
            XCTAssertEqual(QuickLaunchAction.resolve(.userPreferred, defaults: defaults), action)
        }
    }

    func testEveryActionHasADisplayName() {
        XCTAssertTrue(QuickLaunchAction.allCases.allSatisfy { !$0.displayName.isEmpty })
    }
}
