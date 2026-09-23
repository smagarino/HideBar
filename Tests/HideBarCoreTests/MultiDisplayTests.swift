import XCTest
@testable import HideBarCore

/// A real arrangement seen during development: a 14-inch MacBook Pro with an
/// external display placed above it. Screen coordinates put y = 0 at the
/// bottom, so the external display occupies the higher y values and its menu
/// bar sits more than a thousand points above the laptop's.
private let laptop = ScreenBounds(
    frame: CGRect(x: 0, y: 0, width: 1800, height: 1169),
    visibleMaxY: 1131)                                   // menu bar 1131...1169

private let external = ScreenBounds(
    frame: CGRect(x: 0, y: 1169, width: 2560, height: 1440),
    visibleMaxY: 2571)                                   // menu bar 2571...2609

private let screens = [laptop, external]

final class MultiDisplayScreenSelectionTests: XCTestCase {

    func testPicksTheLaptopForAPointOnTheLaptop() {
        XCTAssertEqual(
            ScreenRules.screen(containing: CGPoint(x: 900, y: 600),
                               screens: screens, main: laptop),
            laptop)
    }

    func testPicksTheExternalDisplayForAPointOnIt() {
        XCTAssertEqual(
            ScreenRules.screen(containing: CGPoint(x: 900, y: 2000),
                               screens: screens, main: laptop),
            external)
    }

    /// Displays can be arranged with gaps between them. A pointer crossing one
    /// belongs to no screen, and the rules still need an answer.
    func testFallsBackToTheMainScreenInAGap() {
        let offset = ScreenBounds(
            frame: CGRect(x: 3000, y: 0, width: 1000, height: 1000), visibleMaxY: 975)
        XCTAssertEqual(
            ScreenRules.screen(containing: CGPoint(x: 2500, y: 500),
                               screens: [laptop, offset], main: laptop),
            laptop)
    }

    func testFallsBackWhenThereAreNoScreens() {
        XCTAssertEqual(
            ScreenRules.screen(containing: .zero, screens: [], main: laptop), laptop)
        XCTAssertNil(
            ScreenRules.screen(containing: .zero, screens: [], main: nil))
    }
}

final class MultiDisplayHoverTests: XCTestCase {

    /// Resolve the screen first, exactly as the app does, then decide.
    private func decide(pointer: CGPoint, chevron: CGRect?, reveal: Reveal,
                        revealedByHover: Bool) -> HoverDecision {
        guard let screen = ScreenRules.screen(containing: pointer,
                                              screens: screens, main: laptop) else {
            return .doNothing
        }
        return HoverRules.decide(pointer: pointer, chevron: chevron,
                                 screenMaxY: screen.frame.maxY,
                                 visibleMaxY: screen.visibleMaxY,
                                 reveal: reveal, revealedByHover: revealedByHover)
    }

    /// The menu bar, and the chevron, can live on the external display.
    func testHoverRevealsOnTheExternalDisplay() {
        let chevron = CGRect(x: 2200, y: 2571, width: 26, height: 38)
        XCTAssertEqual(
            decide(pointer: CGPoint(x: 2210, y: 2590), chevron: chevron,
                   reveal: .none, revealedByHover: false),
            .reveal)
    }

    /// The bug this guards: judging every pointer against the main screen's
    /// menu bar. This point sits low on the external display, far below its
    /// menu bar at 2571, but it is above the laptop's bottom edge of 1131.
    /// Against the wrong screen it reads as "still in the menu bar", so a
    /// hover reveal would never hide again.
    func testPointLowOnTheExternalDisplayIsNotInItsMenuBar() {
        XCTAssertGreaterThan(CGFloat(1200),
                             MenuBarGeometry.bottomEdge(screenMaxY: laptop.frame.maxY,
                                                        visibleMaxY: laptop.visibleMaxY),
                             "the point must look like the menu bar on the wrong screen")
        XCTAssertEqual(
            decide(pointer: CGPoint(x: 500, y: 1200), chevron: nil,
                   reveal: .hidden, revealedByHover: true),
            .collapse)
    }

    /// The mirror case: a point in the laptop's menu bar must still reveal,
    /// even though the external display's menu bar is far higher.
    func testLaptopMenuBarStillWorksWithAnExternalDisplayAttached() {
        let chevron = CGRect(x: 1549, y: 1131, width: 26, height: 38)
        XCTAssertEqual(
            decide(pointer: CGPoint(x: 1560, y: 1150), chevron: chevron,
                   reveal: .none, revealedByHover: false),
            .reveal)
    }
}

final class MultiDisplayOutsideClickTests: XCTestCase {

    private func shouldCollapse(_ pointer: CGPoint) -> Bool {
        guard let screen = ScreenRules.screen(containing: pointer,
                                              screens: screens, main: laptop) else {
            return false
        }
        return OutsideClickRules.shouldCollapse(pointer: pointer,
                                               screenMaxY: screen.frame.maxY,
                                               visibleMaxY: screen.visibleMaxY)
    }

    func testClickInTheExternalMenuBarDoesNotCollapse() {
        XCTAssertFalse(shouldCollapse(CGPoint(x: 900, y: 2590)))
    }

    /// Same trap as the hover case: this is a click in ordinary window space on
    /// the external display, which the laptop's geometry would call a menu bar.
    func testClickLowOnTheExternalDisplayCollapses() {
        XCTAssertTrue(shouldCollapse(CGPoint(x: 900, y: 1200)))
    }
}
