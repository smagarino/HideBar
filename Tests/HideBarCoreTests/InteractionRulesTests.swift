import XCTest
@testable import HideBarCore

/// Numbers taken from a real 14-inch MacBook Pro: a 1169 point tall screen
/// whose visible area starts 38 points down, under a 38 point menu bar.
private let screenMaxY: CGFloat = 1169
private let visibleMaxY: CGFloat = 1131
private let inMenuBar = CGPoint(x: 900, y: 1150)
private let belowMenuBar = CGPoint(x: 900, y: 600)
private let chevron = CGRect(x: 1549, y: 1131, width: 26, height: 38)

// MARK: - Clicks

final class ClickRouterTests: XCTestCase {

    func testRightClickAlwaysOpensTheMenu() {
        for optionHeld in [true, false] {
            for hasSection in [true, false] {
                XCTAssertEqual(
                    ClickRouter.action(isRightClick: true, optionHeld: optionHeld,
                                       hasAlwaysHiddenSection: hasSection),
                    .showMenu)
            }
        }
    }

    func testPlainClickTogglesTheHiddenSection() {
        XCTAssertEqual(
            ClickRouter.action(isRightClick: false, optionHeld: false,
                               hasAlwaysHiddenSection: true),
            .toggleHiddenSection)
    }

    func testOptionClickReachesTheAlwaysHiddenSection() {
        XCTAssertEqual(
            ClickRouter.action(isRightClick: false, optionHeld: true,
                               hasAlwaysHiddenSection: true),
            .toggleAlwaysHiddenSection)
    }

    /// Without that section there is nothing for option to reach, so the click
    /// must still do the ordinary thing rather than nothing at all.
    func testOptionClickIsOrdinaryWithoutTheSection() {
        XCTAssertEqual(
            ClickRouter.action(isRightClick: false, optionHeld: true,
                               hasAlwaysHiddenSection: false),
            .toggleHiddenSection)
    }
}

// MARK: - Reveal transitions

final class RevealMachineTests: XCTestCase {

    func testCollapseAlwaysEndsHidden() {
        for state in Reveal.allCases {
            XCTAssertEqual(RevealMachine.next(from: state, command: .collapse), .none)
        }
    }

    func testShowAllAlwaysEndsShowingEverything() {
        for state in Reveal.allCases {
            XCTAssertEqual(RevealMachine.next(from: state, command: .showAll), .all)
        }
    }

    /// A trigger or a hover calls expand. If that stepped back from showing
    /// everything, a trigger firing would hide the always-hidden section again
    /// while the user was looking at it.
    func testExpandNeverStepsBackFromShowingEverything() {
        XCTAssertEqual(RevealMachine.next(from: .all, command: .expand), .all)
        XCTAssertEqual(RevealMachine.next(from: .none, command: .expand), .hidden)
        XCTAssertEqual(RevealMachine.next(from: .hidden, command: .expand), .hidden)
    }

    func testTogglingTheHiddenSection() {
        XCTAssertEqual(RevealMachine.next(from: .none, command: .toggleHiddenSection), .hidden)
        XCTAssertEqual(RevealMachine.next(from: .hidden, command: .toggleHiddenSection), .none)
        XCTAssertEqual(RevealMachine.next(from: .all, command: .toggleHiddenSection), .none)
    }

    func testTogglingTheAlwaysHiddenSection() {
        XCTAssertEqual(RevealMachine.next(from: .none, command: .toggleAlwaysHiddenSection), .all)
        XCTAssertEqual(RevealMachine.next(from: .all, command: .toggleAlwaysHiddenSection), .none)
        XCTAssertEqual(RevealMachine.next(from: .hidden, command: .toggleAlwaysHiddenSection), .all)
    }
}

// MARK: - The self-hide guard

final class CollapseGuardTests: XCTestCase {

    func testAllowsCollapseWhenTheChevronSitsRightOfTheSeparator() {
        XCTAssertTrue(CollapseGuard.mayCollapse(toggleMinX: 1549, separatorMinX: 1513))
    }

    /// The bug this guards: collapsing here pushes the chevron off-screen with
    /// everything else, and the saved positions restore that on every launch.
    func testRefusesCollapseWhenTheChevronSitsLeftOfTheSeparator() {
        XCTAssertFalse(CollapseGuard.mayCollapse(toggleMinX: 1200, separatorMinX: 1513))
    }

    func testAllowsCollapseWhenThePositionsAreUnknown() {
        XCTAssertTrue(CollapseGuard.mayCollapse(toggleMinX: nil, separatorMinX: 1513))
        XCTAssertTrue(CollapseGuard.mayCollapse(toggleMinX: 1549, separatorMinX: nil))
    }
}

// MARK: - Menu bar geometry

final class MenuBarGeometryTests: XCTestCase {

    func testBottomEdgeUsesTheReportedInset() {
        XCTAssertEqual(
            MenuBarGeometry.bottomEdge(screenMaxY: screenMaxY, visibleMaxY: visibleMaxY),
            1131)
    }

    /// A screen that reports no inset would otherwise make the menu bar zero
    /// points tall, and every hover would miss.
    func testBottomEdgeFallsBackToAMinimumHeight() {
        XCTAssertEqual(
            MenuBarGeometry.bottomEdge(screenMaxY: 1000, visibleMaxY: 1000),
            1000 - MenuBarGeometry.minimumHeight)
    }

    func testContains() {
        XCTAssertTrue(MenuBarGeometry.contains(point: inMenuBar,
                                               screenMaxY: screenMaxY, visibleMaxY: visibleMaxY))
        XCTAssertFalse(MenuBarGeometry.contains(point: belowMenuBar,
                                                screenMaxY: screenMaxY, visibleMaxY: visibleMaxY))
    }
}

// MARK: - Hover

final class HoverRulesTests: XCTestCase {

    private func decide(_ pointer: CGPoint, reveal: Reveal,
                        revealedByHover: Bool = false) -> HoverDecision {
        HoverRules.decide(pointer: pointer, chevron: chevron,
                          screenMaxY: screenMaxY, visibleMaxY: visibleMaxY,
                          reveal: reveal, revealedByHover: revealedByHover)
    }

    func testPointerOnTheChevronReveals() {
        XCTAssertEqual(decide(CGPoint(x: 1560, y: 1150), reveal: .none), .reveal)
    }

    func testPointerJustOutsideTheChevronStillReveals() {
        XCTAssertEqual(decide(CGPoint(x: chevron.minX - 3, y: 1150), reveal: .none), .reveal)
    }

    func testPointerFarFromTheChevronDoesNothing() {
        XCTAssertEqual(decide(CGPoint(x: 400, y: 1150), reveal: .none), .doNothing)
    }

    func testAlreadyRevealedDoesNotRevealAgain() {
        XCTAssertEqual(decide(CGPoint(x: 1560, y: 1150), reveal: .hidden), .doNothing)
    }

    func testLeavingTheMenuBarCollapsesAHoverReveal() {
        XCTAssertEqual(decide(belowMenuBar, reveal: .hidden, revealedByHover: true), .collapse)
    }

    /// The bug this guards: a reveal the user clicked for must survive the
    /// pointer moving away, or clicking the chevron would be useless.
    func testLeavingTheMenuBarKeepsAClickedReveal() {
        XCTAssertEqual(decide(belowMenuBar, reveal: .hidden, revealedByHover: false), .doNothing)
    }
}

// MARK: - Clicks elsewhere

final class OutsideClickRulesTests: XCTestCase {

    /// The bug this guards: revealing an icon and then clicking it would pull
    /// the icon away mid-click.
    func testClickInsideTheMenuBarDoesNotCollapse() {
        XCTAssertFalse(OutsideClickRules.shouldCollapse(
            pointer: inMenuBar, screenMaxY: screenMaxY, visibleMaxY: visibleMaxY))
    }

    func testClickElsewhereCollapses() {
        XCTAssertTrue(OutsideClickRules.shouldCollapse(
            pointer: belowMenuBar, screenMaxY: screenMaxY, visibleMaxY: visibleMaxY))
    }
}
