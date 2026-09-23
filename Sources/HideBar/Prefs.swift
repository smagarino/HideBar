import Foundation

/// Thin typed wrapper over UserDefaults. Keys are namespaced so the
/// status-item autosave entries (managed by AppKit) never collide with ours.
enum Prefs {
    private static let d = UserDefaults.standard

    private enum Key {
        static let collapsed = "hidebar.state.collapsed"
        static let autoHideDelay = "hidebar.pref.autoHideDelay"
        static let hideOnOutsideClick = "hidebar.pref.hideOnOutsideClick"
        static let slimMode = "hidebar.pref.slimMode"
        static let hotkeyEnabled = "hidebar.pref.hotkeyEnabled"
    }

    /// Whether the hidden section was collapsed when we last quit.
    static var collapsed: Bool {
        get { d.object(forKey: Key.collapsed) as? Bool ?? true }
        set { d.set(newValue, forKey: Key.collapsed) }
    }

    /// Seconds to stay expanded before auto-collapsing. 0 disables the timer.
    static var autoHideDelay: TimeInterval {
        get { d.object(forKey: Key.autoHideDelay) as? TimeInterval ?? 10 }
        set { d.set(newValue, forKey: Key.autoHideDelay) }
    }

    /// Collapse again when the user clicks anywhere outside the menu bar.
    static var hideOnOutsideClick: Bool {
        get { d.object(forKey: Key.hideOnOutsideClick) as? Bool ?? true }
        set { d.set(newValue, forKey: Key.hideOnOutsideClick) }
    }

    /// Shrink both status items so they fit an already crowded menu bar.
    /// A MacBook with a notch can leave less room than the normal size needs.
    static var slimMode: Bool {
        get { d.object(forKey: Key.slimMode) as? Bool ?? false }
        set { d.set(newValue, forKey: Key.slimMode) }
    }

    /// Toggle with a global keyboard shortcut. Useful in slim mode, where the
    /// chevron is a small target.
    static var hotkeyEnabled: Bool {
        get { d.object(forKey: Key.hotkeyEnabled) as? Bool ?? true }
        set { d.set(newValue, forKey: Key.hotkeyEnabled) }
    }
}
