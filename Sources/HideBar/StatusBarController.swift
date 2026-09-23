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
    private static let expandedWidth: CGFloat = 20

    private var toggleItem: NSStatusItem!
    private var separatorItem: NSStatusItem!

    private var autoHideTimer: Timer?
    private var outsideClickMonitor: Any?

    private(set) var collapsed: Bool = Prefs.collapsed {
        didSet {
            Prefs.collapsed = collapsed
            render()
            collapsed ? stopWatchers() : startWatchers()
        }
    }

    // MARK: - Setup

    func install() {
        // Order matters: a newly created item is placed to the LEFT of existing
        // ones, so creating the toggle first leaves the separator on its left.
        toggleItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        toggleItem.autosaveName = "hidebar.toggle"
        if let button = toggleItem.button {
            button.target = self
            button.action = #selector(toggleClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        separatorItem = NSStatusBar.system.statusItem(withLength: Self.expandedWidth)
        separatorItem.autosaveName = "hidebar.separator"
        separatorItem.button?.image = symbol("ellipsis.circle", "Separator")

        render()
        if !collapsed { startWatchers() }
    }

    private func symbol(_ name: String, _ label: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: label)
        image?.isTemplate = true
        return image
    }

    // MARK: - Rendering

    private func render() {
        if collapsed {
            separatorItem.length = Self.collapsedWidth
            separatorItem.button?.image = nil
            toggleItem.button?.image = symbol("chevron.left", "Show hidden menu bar items")
            toggleItem.button?.toolTip = "Show hidden menu bar items"
        } else {
            separatorItem.length = Self.expandedWidth
            separatorItem.button?.image = symbol("ellipsis.circle", "Separator")
            toggleItem.button?.image = symbol("chevron.right", "Hide menu bar items")
            toggleItem.button?.toolTip = "Hide menu bar items"
        }
    }

    // MARK: - Actions

    @objc private func toggleClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else {
            collapsed ? expand() : collapse(userInitiated: true)
        }
    }

    func expand() { if collapsed { collapsed = false } }

    /// Collapsing while the toggle sits to the LEFT of the separator would push
    /// the toggle off-screen too, leaving no way to bring it back — and
    /// `autosaveName` would faithfully restore that broken layout on relaunch.
    func collapse(userInitiated: Bool = false) {
        guard !collapsed else { return }
        guard toggleIsRightOfSeparator else {
            if userInitiated { warnAboutTogglePosition() }
            return
        }
        collapsed = true
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
