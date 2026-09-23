import AppKit
import HideBarCore

/// Drives the two status items that implement hiding.
///
/// The technique uses no private API: status items are laid out right-to-left,
/// so a separator item stretched to an enormous width pushes everything to its
/// left beyond the edge of the screen, where the system stops drawing it.
/// The user chooses what gets hidden by Cmd-dragging icons across the separator.
final class StatusBarController {

    /// Separator widths come from LayoutRules, which the tests cover.
    private static var expandedWidth: CGFloat {
        LayoutRules.restingWidth(slim: Prefs.slimMode)
    }

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

    /// The screen the pointer is on, reduced to the values the rules need.
    private func screenBounds(under point: CGPoint) -> ScreenBounds? {
        ScreenRules.screen(
            containing: point,
            screens: NSScreen.screens.map {
                ScreenBounds(frame: $0.frame, visibleMaxY: $0.visibleFrame.maxY)
            },
            main: NSScreen.main.map {
                ScreenBounds(frame: $0.frame, visibleMaxY: $0.visibleFrame.maxY)
            })
    }

    private func pointerMoved() {
        let point = NSEvent.mouseLocation
        guard let screen = screenBounds(under: point) else { return }

        switch HoverRules.decide(pointer: point,
                                 chevron: toggleItem.button?.window?.frame,
                                 screenMaxY: screen.frame.maxY,
                                 visibleMaxY: screen.visibleMaxY,
                                 reveal: reveal,
                                 revealedByHover: revealedByHover) {
        case .doNothing:
            break
        case .reveal:
            revealedByHover = true
            expand()
        case .collapse:
            collapse()
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

        let plan = LayoutRules.layout(for: reveal, slim: Prefs.slimMode)
        let showsHidden = (reveal != .none)

        separatorItem.length = plan.hidden
        separatorItem.button?.image = plan.showsHiddenImage
            ? symbol("ellipsis.circle", "Separator") : nil

        if let always = alwaysHiddenSeparator {
            always.length = plan.alwaysHidden
            always.button?.image = plan.showsAlwaysHiddenImage
                ? symbol("eye.slash.circle", "Always hidden separator") : nil
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
        switch ClickRouter.action(isRightClick: event.type == .rightMouseUp,
                                  optionHeld: event.modifierFlags.contains(.option),
                                  hasAlwaysHiddenSection: alwaysHiddenSeparator != nil) {
        case .showMenu:
            showMenu()
        case .toggleAlwaysHiddenSection:
            reveal = RevealMachine.next(from: reveal, command: .toggleAlwaysHiddenSection)
        case .toggleHiddenSection:
            collapsed ? expand() : collapse(userInitiated: true)
        }
    }

    func expand() { reveal = RevealMachine.next(from: reveal, command: .expand) }

    /// Show every item, including the always-hidden section.
    func showAll() { reveal = RevealMachine.next(from: reveal, command: .showAll) }

    /// Collapsing while the toggle sits to the LEFT of the separator would push
    /// the toggle off-screen too, leaving no way to bring it back — and
    /// `autosaveName` would faithfully restore that broken layout on relaunch.
    func collapse(userInitiated: Bool = false) {
        guard reveal != .none else { return }
        guard toggleIsRightOfSeparator else {
            if userInitiated { warnAboutTogglePosition() }
            return
        }
        reveal = RevealMachine.next(from: reveal, command: .collapse)
    }

    private var toggleIsRightOfSeparator: Bool {
        CollapseGuard.mayCollapse(
            toggleMinX: toggleItem.button?.window?.frame.minX,
            separatorMinX: separatorItem.button?.window?.frame.minX)
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
            let point = NSEvent.mouseLocation
            guard let self, let screen = self.screenBounds(under: point) else { return }
            if OutsideClickRules.shouldCollapse(pointer: point,
                                                screenMaxY: screen.frame.maxY,
                                                visibleMaxY: screen.visibleMaxY) {
                self.collapse()
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
