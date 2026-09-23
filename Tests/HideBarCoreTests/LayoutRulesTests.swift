import XCTest
@testable import HideBarCore

final class LayoutRulesTests: XCTestCase {

    /// The bug this guards: stretching both separators at once overflows the
    /// menu bar layout, and macOS then parked the chevron behind the camera
    /// notch, where it never drew it. The app looked broken while running fine.
    func testNeverStretchesBothSeparatorsAtOnce() {
        for reveal in Reveal.allCases {
            let plan = LayoutRules.layout(for: reveal)
            let bothStretched = plan.hidden == LayoutRules.stretchedWidth
                && plan.alwaysHidden == LayoutRules.stretchedWidth
            XCTAssertFalse(bothStretched, "\(reveal) stretches both separators")
        }
    }

    func testCollapsedStretchesOnlyTheFirstSeparator() {
        let plan = LayoutRules.layout(for: .none)
        XCTAssertEqual(plan.hidden, LayoutRules.stretchedWidth)
        XCTAssertEqual(plan.alwaysHidden, LayoutRules.restingWidth(slim: false))
        XCTAssertFalse(plan.showsHiddenImage, "a stretched separator draws no image")
    }

    /// Showing the ordinary section must still push the always-hidden one away.
    func testHiddenStateStretchesTheSecondSeparator() {
        let plan = LayoutRules.layout(for: .hidden)
        XCTAssertEqual(plan.hidden, LayoutRules.restingWidth(slim: false))
        XCTAssertEqual(plan.alwaysHidden, LayoutRules.stretchedWidth)
        XCTAssertTrue(plan.showsHiddenImage)
        XCTAssertFalse(plan.showsAlwaysHiddenImage)
    }

    func testShowAllRestsBothSeparators() {
        let plan = LayoutRules.layout(for: .all)
        XCTAssertEqual(plan.hidden, LayoutRules.restingWidth(slim: false))
        XCTAssertEqual(plan.alwaysHidden, LayoutRules.restingWidth(slim: false))
        XCTAssertTrue(plan.showsHiddenImage)
        XCTAssertTrue(plan.showsAlwaysHiddenImage)
    }

    func testSlimModeNarrowsTheRestingSeparator() {
        XCTAssertLessThan(LayoutRules.restingWidth(slim: true),
                          LayoutRules.restingWidth(slim: false))
        XCTAssertEqual(LayoutRules.layout(for: .all, slim: true).hidden,
                       LayoutRules.restingWidth(slim: true))
    }

    /// Slim mode must never shrink the separator that does the hiding.
    func testSlimModeDoesNotWeakenHiding() {
        XCTAssertEqual(LayoutRules.layout(for: .none, slim: true).hidden,
                       LayoutRules.stretchedWidth)
        XCTAssertEqual(LayoutRules.layout(for: .hidden, slim: true).alwaysHidden,
                       LayoutRules.stretchedWidth)
    }
}
