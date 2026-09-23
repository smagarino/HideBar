import Foundation

/// Thin typed wrapper over UserDefaults. Keys are namespaced so the
/// status-item autosave entries (managed by AppKit) never collide with ours.
enum Prefs {
    private static let d = UserDefaults.standard

    private enum Key {
        static let collapsed = "hidebar.state.collapsed"
        static let autoHideDelay = "hidebar.pref.autoHideDelay"
        static let hideOnOutsideClick = "hidebar.pref.hideOnOutsideClick"
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
}
