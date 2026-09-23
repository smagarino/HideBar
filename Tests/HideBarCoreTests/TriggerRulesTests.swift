import XCTest
@testable import HideBarCore

final class TriggerRulesTests: XCTestCase {

    private func decide(_ state: inout TriggerState, _ snapshot: PowerSnapshot,
                        power: Bool = true, low: Bool = true) -> TriggerOutcome {
        TriggerRules.decide(state: &state, snapshot: snapshot,
                            revealOnPowerChange: power, revealOnLowBattery: low)
    }

    /// The bug this guards: the system sends a power notification for every
    /// percentage change. Acting on each one reopens the menu bar every few
    /// minutes, which makes the app unusable.
    func testPercentageChangeAloneDoesNotReveal() {
        var state = TriggerState(wasOnBattery: true)
        for percent in [95, 94, 93, 60, 45] {
            let outcome = decide(&state, PowerSnapshot(onBattery: true, percent: percent))
            XCTAssertFalse(outcome.shouldReveal, "revealed at \(percent)% with no transition")
        }
    }

    func testUnpluggingReveals() {
        var state = TriggerState(wasOnBattery: false)
        let outcome = decide(&state, PowerSnapshot(onBattery: true, percent: 80))
        XCTAssertTrue(outcome.powerChanged)
    }

    func testPluggingInReveals() {
        var state = TriggerState(wasOnBattery: true)
        let outcome = decide(&state, PowerSnapshot(onBattery: false, percent: 80))
        XCTAssertTrue(outcome.powerChanged)
    }

    /// The first reading after launch has no previous state to compare with.
    /// It must not count as a transition, or the app would reveal on every start.
    func testFirstReadingIsNotATransition() {
        var state = TriggerState()
        let outcome = decide(&state, PowerSnapshot(onBattery: true, percent: 80))
        XCTAssertFalse(outcome.powerChanged)
        XCTAssertEqual(state.wasOnBattery, true, "the baseline must still be recorded")
    }

    func testLowBatteryFiresOnceUntilCharged() {
        var state = TriggerState(wasOnBattery: true)
        XCTAssertTrue(decide(&state, PowerSnapshot(onBattery: true, percent: 20)).lowBattery)
        XCTAssertFalse(decide(&state, PowerSnapshot(onBattery: true, percent: 19)).lowBattery,
                       "a second warning during one discharge is nagging")
        XCTAssertFalse(decide(&state, PowerSnapshot(onBattery: true, percent: 15)).lowBattery)

        // Charging re-arms it for the next discharge.
        _ = decide(&state, PowerSnapshot(onBattery: false, percent: 80))
        XCTAssertTrue(decide(&state, PowerSnapshot(onBattery: true, percent: 18)).lowBattery)
    }

    func testLowBatteryIgnoredWhileOnMainsPower() {
        var state = TriggerState(wasOnBattery: false)
        let outcome = decide(&state, PowerSnapshot(onBattery: false, percent: 5))
        XCTAssertFalse(outcome.lowBattery, "charging at 5% is not a warning")
    }

    func testSettingsOffSuppressEverything() {
        var state = TriggerState(wasOnBattery: false)
        let outcome = decide(&state, PowerSnapshot(onBattery: true, percent: 5),
                             power: false, low: false)
        XCTAssertFalse(outcome.shouldReveal)
    }

    func testThresholdBoundary() {
        var atThreshold = TriggerState(wasOnBattery: true)
        XCTAssertTrue(decide(&atThreshold, PowerSnapshot(onBattery: true, percent: 20)).lowBattery)

        var above = TriggerState(wasOnBattery: true)
        XCTAssertFalse(decide(&above, PowerSnapshot(onBattery: true, percent: 21)).lowBattery)
    }
}
