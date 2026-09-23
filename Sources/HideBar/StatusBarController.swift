import AppKit

/// Drives the two status items that implement hiding.
///
/// The technique uses no private API: status items are laid out right-to-left,
/// so a separator item stretched to an enormous width pushes everything to its
/// left beyond the edge of the screen, where the system stops drawing it.
/// The user chooses what gets hidden by Cmd-dragging icons across the separator.
final class StatusBarController {

    /// Width the separator takes when collapsed. AppKit clamps this to the
    /// space actually available, which is exactly what we want.
    private static let collapsedWidth: CGFloat = 10_000
    /// Width of the separator while expanded. Slim mode trades a comfortable
    /// click target for roughly 45 points of menu bar space.
    private static var expandedWidth: CGFloat { Prefs.slimMode ? 1 : 20 }

    /// Width of the toggle. Normal mode lets the image size it.
    private static var toggleWidth: CGFloat { NSStatusItem.variableLength }

    private var toggleItem: NSStatusItem!
    private var separatorItem: NSStatusItem!

    /// Second separator. Items parked to its left stay hidden even while the
    /// ordinary hidden section shows. Created only when the user asks for it.
    private var alwaysHiddenSeparator: NSStatusItem?

    private var autoHideTimer: Timer?
    private var outsideClickMonitor: Any?
    private var hoverMonitor: Any?
    private var localHoverMonitor: Any?

    /// True while the icons are showing only because the pointer is on the
    /// chevron. Such a reveal collapses again when the pointer leaves the menu
    /// bar, which a reveal the user clicked for must not do.
    private var revealedByHover = false

    /// How much of the menu bar is on show.
    enum Reveal {
        /// Only the items to the right of the first separator.
        case none
        /// Plus the ordinary hidden section.
        case hidden
        /// Plus the always-hidden section.
        case all
    }

    private(set) var reveal: Reveal = Prefs.collapsed ? .none : .hidden {
        didSet {
            // Only the ordinary hidden state is restored at launch. Starting up
            // with everything on show would defeat the point of the app.
            Prefs.collapsed = (reveal == .none)
            if reveal == .none { revealedByHover = false }
            render()
            reveal == .none ? stopWatchers() : startWatchers()
        }
    }

    var collapsed: Bool { reveal == .none }

    // MARK: - Setup

    func install() {
        // Order matters: a newly created item is placed to the LEFT of existing
        // ones, so creating the toggle first leaves the separator on its left.
        toggleItem = NSStatusBar.system.statusItem(withLength: Self.toggleWidth)
        toggleItem.autosaveName = "hidebar.toggle"
        if let button = toggleItem.button {
            button.target = self
            button.action = #selector(toggleClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        separatorItem = NSStatusBar.system.statusItem(withLength: Self.expandedWidth)
        separatorItem.autosaveName = "hidebar.separator"
        separatorItem.button?.image = symbol("ellipsis.circle", "Separator")

        applyAlwaysHiddenSection()
        render()
        if !collapsed { startWatchers() }
        applyHotkeyPreference()
        applyHoverPreference()
        applyTriggerPreferences()
    }

    /// Reveal the icons when a system trigger fires. The auto-hide timer, or
    /// the next click, hides them again.
    func applyTriggerPreferences() {
        TriggerMonitor.shared.onTrigger = { [weak self] _ in self?.expand() }
        TriggerMonitor.shared.refresh()
    }

    // MARK: - Hover to reveal

    /// Start or stop watching the pointer, to match the preference.
    func applyHoverPreference() {
        for monitor in [hoverMonitor, localHoverMonitor].compactMap({ $0 }) {
            NSEvent.removeMonitor(monitor)
        }
        hoverMonitor = nil
        localHoverMonitor = nil
        guard Prefs.hoverToReveal else { return }

        // Mouse monitors need no Accessibility permission. Keyboard ones do.
        // A global monitor never sees events that go to this app, and the
        // pointer sitting on our own chevron produces exactly those, so watch
        // both streams.
        hoverMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) {
            [weak self] _ in self?.pointerMoved()
        }
        localHoverMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) {
            [weak self] event in
            self?.pointerMoved()
            return event
        }
    }

    private func pointerMoved() {
        let point = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(point) })
                ?? NSScreen.main else { return }

        // Cheap test first. This runs on every mouse move.
        let menuBarBottom = screen.frame.maxY - max(screen.frame.maxY - screen.visibleFrame.maxY, 25)
        guard point.y >= menuBarBottom else {
            if revealedByHover { collapse() }   // pointer left the menu bar
            return
        }

        guard collapsed, let frame = toggleItem.button?.window?.frame else { return }
        if frame.insetBy(dx: -6, dy: 0).contains(point) {
            revealedByHover = true
            expand()
        }
    }

    /// Register or drop the global shortcut to match the preference.
    func applyHotkeyPreference() {
        if Prefs.hotkeyEnabled {
            let ok = HotKey.shared.register { [weak self] in
                guard let self else { return }
                self.collapsed ? self.expand() : self.collapse(userInitiated: true)
            }
            if !ok { Prefs.hotkeyEnabled = false }
        } else {
            HotKey.shared.unregister()
        }
    }

    private func symbol(_ name: String, _ label: String) -> NSImage? {
        let config = NSImage.SymbolConfiguration(
            pointSize: Prefs.slimMode ? 9 : 13, weight: .regular)
        let image = NSImage(systemSymbolName: name, accessibilityDescription: label)?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        return image
    }

    /// Re-apply the widths after slim mode changes.
    func refreshSizing() {
        toggleItem.length = Self.toggleWidth
        render()
    }

    // MARK: - Rendering

    private func render() {
        toggleItem.length = Self.toggleWidth

        let showsHidden = (reveal != .none)
        separatorItem.length = showsHidden ? Self.expandedWidth : Self.collapsedWidth
        separatorItem.button?.image = showsHidden ? symbol("ellipsis.circle", "Separator") : nil

        if let always = alwaysHiddenSeparator {
            // Stretch it only while the ordinary section shows and this one must
            // not. When everything is collapsed the first separator already
            // pushes this one off-screen, so leave it small: two enormous items
            // at once overflow the layout.
            let mustPush = (reveal == .hidden)
            always.length = mustPush ? Self.collapsedWidth : Self.expandedWidth
            always.button?.image = mustPush
                ? nil : symbol("eye.slash.circle", "Always hidden separator")
        }

        toggleItem.button?.image = symbol(
            showsHidden ? "chevron.right" : "chevron.left",
            showsHidden ? "Hide menu bar items" : "Show hidden menu bar items")
        toggleItem.button?.toolTip = showsHidden
            ? "Hide menu bar items" : "Show hidden menu bar items"
    }

    /// Create or remove the second separator to match the preference.
    func applyAlwaysHiddenSection() {
        if Prefs.alwaysHiddenSection {
            guard alwaysHiddenSeparator == nil else { return }
            // Created last, so it lands to the left of the first separator.
            let item = NSStatusBar.system.statusItem(withLength: Self.expandedWidth)
            item.autosaveName = "hidebar.alwaysHiddenSeparator"
            item.button?.image = symbol("eye.slash.circle", "Always hidden separator")
            item.button?.toolTip = "Items left of this stay hidden"
            alwaysHiddenSeparator = item
        } else {
            if let item = alwaysHiddenSeparator {
                NSStatusBar.system.removeStatusItem(item)
            }
            alwaysHiddenSeparator = nil
            if reveal == .all { reveal = .hidden }
        }
        render()
    }

    // MARK: - Actions

    @objc private func toggleClicked() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showMenu()
            return
        }
        // Option-click reaches the always-hidden section.
        if event.modifierFlags.contains(.option), alwaysHiddenSeparator != nil {
            reveal = (reveal == .all) ? .none : .all
            return
        }
        collapsed ? expand() : collapse(userInitiated: true)
    }

    func expand() { if reveal == .none { reveal = .hidden } }

    /// Show every item, including the always-hidden section.
    func showAll() { reveal = .all }

    /// Collapsing while the toggle sits to the LEFT of the separator would push
    /// the toggle off-screen too, leaving no way to bring it back — and
    /// `autosaveName` would faithfully restore that broken layout on relaunch.
    func collapse(userInitiated: Bool = false) {
        guard reveal != .none else { return }
        guard toggleIsRightOfSeparator else {
            if userInitiated { warnAboutTogglePosition() }
            return
        }
        reveal = .none
    }

    private var toggleIsRightOfSeparator: Bool {
        guard let toggleX = toggleItem.button?.window?.frame.minX,
              let separatorX = separatorItem.button?.window?.frame.minX
        else { return true }   // can't tell; don't block the user
        return toggleX > separatorX
    }

    private func warnAboutTogglePosition() {
        let alert = NSAlert()
        alert.messageText = "Move the chevron back to the right"
        alert.informativeText = """
            The chevron is currently to the left of the \u{22EF} separator, so hiding             would hide the chevron itself and leave no way to unhide.

            Hold \u{2318} and drag the chevron to the right of the separator, then try again.
            """
        alert.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    // MARK: - Auto-collapse

    /// While expanded, collapse again after a delay and/or when the user clicks
    /// somewhere other than the menu bar. Only *mouse* global monitors are used;
    /// unlike keyboard monitors they require no Accessibility permission.
    private func startWatchers() {
        stopWatchers()

        let delay = Prefs.autoHideDelay
        if delay > 0 {
            autoHideTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                self?.collapse()
            }
        }

        guard Prefs.hideOnOutsideClick else { return }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            // Ignore clicks inside the menu bar itself, otherwise revealing an
            // icon and then clicking it would collapse the bar out from under it.
            let point = NSEvent.mouseLocation
            guard let screen = NSScreen.screens.first(where: { $0.frame.contains(point) })
                    ?? NSScreen.main else { return }
            let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
            if point.y < screen.frame.maxY - max(menuBarHeight, 25) {
                self?.collapse()
            }
        }
    }

    private func stopWatchers() {
        // The hover monitor is not a watcher: it must keep running while
        // collapsed, because that is when a hover has to reveal.
        autoHideTimer?.invalidate()
        autoHideTimer = nil
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }

    // MARK: - Menu

    private func showMenu() {
        let menu = AppMenu.build(controller: self)
        // Attaching the menu permanently would swallow left-clicks, so it is
        // attached only for the duration of this one click.
        toggleItem.menu = menu
        toggleItem.button?.performClick(nil)
        toggleItem.menu = nil
    }
}
