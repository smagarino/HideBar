import AppKit
import IOKit.ps
import HideBarCore

/// Watches the system for events worth a glance at the menu bar, and reveals
/// the hidden icons when one happens.
///
/// Every source here is a system notification about this Mac. None of them read
/// another app, so none need the Accessibility permission.
final class TriggerMonitor {
    static let shared = TriggerMonitor()
    private init() {}

    /// Called when a trigger fires. The reason is for the log, not the user.
    var onTrigger: ((String) -> Void)?

    private var runLoopSource: CFRunLoopSource?
    private var screenObserver: NSObjectProtocol?

    /// Carried between readings so a change can be spotted. The decision
    /// itself lives in TriggerRules, which the tests cover.
    private var triggerState = TriggerState()

    // MARK: - Lifecycle

    /// Start or stop each watcher to match the current preferences.
    func refresh() {
        let wantsPower = Prefs.revealOnPowerChange || Prefs.revealOnLowBattery
        wantsPower ? startPowerWatch() : stopPowerWatch()
        Prefs.revealOnDisplayChange ? startScreenWatch() : stopScreenWatch()
    }

    // MARK: - Power

    private func startPowerWatch() {
        guard runLoopSource == nil else { return }
        triggerState = TriggerState(wasOnBattery: currentlyOnBattery())
        guard let source = IOPSNotificationCreateRunLoopSource({ _ in
            DispatchQueue.main.async { TriggerMonitor.shared.powerChanged() }
        }, nil)?.takeRetainedValue() else { return }
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    private func stopPowerWatch() {
        guard let source = runLoopSource else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        runLoopSource = nil
        triggerState = TriggerState()
    }

    /// The power notification also fires for every percentage change, so act
    /// only on a real transition. Otherwise the icons would reveal constantly.
    fileprivate func powerChanged() {
        let snapshot = PowerSnapshot(onBattery: currentlyOnBattery(),
                                     percent: batteryPercent())
        let outcome = TriggerRules.decide(
            state: &triggerState,
            snapshot: snapshot,
            revealOnPowerChange: Prefs.revealOnPowerChange,
            revealOnLowBattery: Prefs.revealOnLowBattery)

        if outcome.powerChanged {
            onTrigger?(snapshot.onBattery ? "switched to battery" : "plugged in")
        }
        if outcome.lowBattery {
            onTrigger?("battery at \(snapshot.percent)%")
        }
    }

    func currentlyOnBattery() -> Bool {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let type = IOPSGetProvidingPowerSourceType(blob)?.takeRetainedValue() as String?
        else { return false }
        return type == kIOPSBatteryPowerValue
    }

    func batteryPercent() -> Int {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else { return 100 }
        for source in sources {
            guard let d = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue()
                    as? [String: Any],
                  let current = d[kIOPSCurrentCapacityKey] as? Int,
                  let maximum = d[kIOPSMaxCapacityKey] as? Int, maximum > 0
            else { continue }
            return current * 100 / maximum
        }
        return 100
    }

    // MARK: - Displays

    private func startScreenWatch() {
        guard screenObserver == nil else { return }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.onTrigger?("display arrangement changed")
        }
    }

    private func stopScreenWatch() {
        guard let observer = screenObserver else { return }
        NotificationCenter.default.removeObserver(observer)
        screenObserver = nil
    }
}
