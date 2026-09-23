/// What the system reported about power at one moment.
public struct PowerSnapshot: Equatable, Sendable {
    public let onBattery: Bool
    public let percent: Int
    public init(onBattery: Bool, percent: Int) {
        self.onBattery = onBattery
        self.percent = percent
    }
}

/// What the last snapshot left behind, so the next one can spot a change.
public struct TriggerState: Equatable, Sendable {
    public var wasOnBattery: Bool?
    public var lowBatteryAlreadyFired: Bool
    public init(wasOnBattery: Bool? = nil, lowBatteryAlreadyFired: Bool = false) {
        self.wasOnBattery = wasOnBattery
        self.lowBatteryAlreadyFired = lowBatteryAlreadyFired
    }
}

public struct TriggerOutcome: Equatable, Sendable {
    public var powerChanged: Bool
    public var lowBattery: Bool
    public var shouldReveal: Bool { powerChanged || lowBattery }
    public init(powerChanged: Bool = false, lowBattery: Bool = false) {
        self.powerChanged = powerChanged
        self.lowBattery = lowBattery
    }
}

/// Decides whether a power reading is worth revealing the menu bar for.
public enum TriggerRules {

    public static let lowBatteryThreshold = 20

    /// The system sends a power notification for every percentage change, not
    /// only for plug events. Firing on each one would reopen the menu bar every
    /// few minutes, so only a real transition counts.
    public static func decide(state: inout TriggerState,
                              snapshot: PowerSnapshot,
                              revealOnPowerChange: Bool,
                              revealOnLowBattery: Bool,
                              threshold: Int = lowBatteryThreshold) -> TriggerOutcome {
        var outcome = TriggerOutcome()

        if revealOnPowerChange, let previous = state.wasOnBattery,
           previous != snapshot.onBattery {
            outcome.powerChanged = true
        }
        state.wasOnBattery = snapshot.onBattery

        guard revealOnLowBattery else { return outcome }

        if snapshot.onBattery && snapshot.percent <= threshold {
            if !state.lowBatteryAlreadyFired {
                state.lowBatteryAlreadyFired = true
                outcome.lowBattery = true
            }
        } else {
            // Re-arm once the Mac charges again, so one discharge warns once.
            state.lowBatteryAlreadyFired = false
        }
        return outcome
    }
}
