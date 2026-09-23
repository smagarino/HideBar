import AppKit
import ServiceManagement

/// Right-click menu on the toggle item.
enum AppMenu {

    private static let delayOptions: [(String, TimeInterval)] = [
        ("Never", 0), ("After 5 seconds", 5), ("After 10 seconds", 10),
        ("After 30 seconds", 30), ("After 1 minute", 60),
    ]

    static func build(controller: StatusBarController) -> NSMenu {
        let menu = NSMenu()
        let handler = MenuHandler.shared
        handler.controller = controller

        let hint = NSMenuItem(
            title: "⌘-drag icons left of the separator to hide them",
            action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)
        menu.addItem(.separator())

        // Auto-hide submenu
        let autoHide = NSMenuItem(title: "Auto-hide", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        for (title, seconds) in delayOptions {
            let item = NSMenuItem(title: title, action: #selector(MenuHandler.setDelay(_:)), keyEquivalent: "")
            item.target = handler
            item.representedObject = seconds
            item.state = (Prefs.autoHideDelay == seconds) ? .on : .off
            sub.addItem(item)
        }
        autoHide.submenu = sub
        menu.addItem(autoHide)

        let outside = NSMenuItem(
            title: "Hide when clicking elsewhere",
            action: #selector(MenuHandler.toggleOutsideClick), keyEquivalent: "")
        outside.target = handler
        outside.state = Prefs.hideOnOutsideClick ? .on : .off
        menu.addItem(outside)

        let alwaysHidden = NSMenuItem(
            title: "Always-hidden section",
            action: #selector(MenuHandler.toggleAlwaysHiddenSection), keyEquivalent: "")
        alwaysHidden.target = handler
        alwaysHidden.state = Prefs.alwaysHiddenSection ? .on : .off
        alwaysHidden.toolTip = "Add a second separator for items you rarely need"
        menu.addItem(alwaysHidden)

        if Prefs.alwaysHiddenSection {
            let showAll = NSMenuItem(
                title: "Show all items",
                action: #selector(MenuHandler.showAllItems), keyEquivalent: "")
            showAll.target = handler
            showAll.toolTip = "Option-click the chevron does the same"
            menu.addItem(showAll)
        }

        menu.addItem(.separator())

        let triggers = NSMenuItem(title: "Reveal automatically", action: nil, keyEquivalent: "")
        let triggerMenu = NSMenu()
        let triggerOptions: [(String, Bool, Selector)] = [
            ("When the power source changes", Prefs.revealOnPowerChange,
             #selector(MenuHandler.togglePowerTrigger)),
            ("When the battery is low", Prefs.revealOnLowBattery,
             #selector(MenuHandler.toggleLowBatteryTrigger)),
            ("When a display is connected", Prefs.revealOnDisplayChange,
             #selector(MenuHandler.toggleDisplayTrigger)),
        ]
        for (title, isOn, action) in triggerOptions {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = handler
            item.state = isOn ? .on : .off
            triggerMenu.addItem(item)
        }
        triggers.submenu = triggerMenu
        menu.addItem(triggers)

        let hover = NSMenuItem(
            title: "Reveal on hover",
            action: #selector(MenuHandler.toggleHoverToReveal), keyEquivalent: "")
        hover.target = handler
        hover.state = Prefs.hoverToReveal ? .on : .off
        hover.toolTip = "Show the icons when the pointer rests on the chevron"
        menu.addItem(hover)

        let slim = NSMenuItem(
            title: "Slim mode (smaller icons)",
            action: #selector(MenuHandler.toggleSlimMode), keyEquivalent: "")
        slim.target = handler
        slim.state = Prefs.slimMode ? .on : .off
        slim.toolTip = "Shrink both icons to fit a crowded menu bar"
        menu.addItem(slim)

        let hotkey = NSMenuItem(
            title: "Keyboard shortcut (\(HotKey.displayName))",
            action: #selector(MenuHandler.toggleHotkey), keyEquivalent: "")
        hotkey.target = handler
        hotkey.state = Prefs.hotkeyEnabled ? .on : .off
        hotkey.toolTip = "Hide and show without clicking the chevron"
        menu.addItem(hotkey)

        let login = NSMenuItem(
            title: "Open at Login",
            action: #selector(MenuHandler.toggleLaunchAtLogin), keyEquivalent: "")
        login.target = handler
        login.state = handler.launchAtLoginEnabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit HideBar", action: #selector(MenuHandler.quit), keyEquivalent: "q")
        quit.target = handler
        menu.addItem(quit)

        return menu
    }
}

/// Target for menu actions. Menu items hold weak targets, so this is kept alive
/// as a singleton rather than as a local of `build`.
final class MenuHandler: NSObject {
    static let shared = MenuHandler()
    weak var controller: StatusBarController?

    var launchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @objc func setDelay(_ sender: NSMenuItem) {
        Prefs.autoHideDelay = sender.representedObject as? TimeInterval ?? 10
    }

    @objc func toggleOutsideClick() {
        Prefs.hideOnOutsideClick.toggle()
    }

    @objc func toggleAlwaysHiddenSection() {
        Prefs.alwaysHiddenSection.toggle()
        controller?.applyAlwaysHiddenSection()
    }

    @objc func showAllItems() {
        controller?.showAll()
    }

    @objc func togglePowerTrigger() {
        Prefs.revealOnPowerChange.toggle()
        controller?.applyTriggerPreferences()
    }

    @objc func toggleLowBatteryTrigger() {
        Prefs.revealOnLowBattery.toggle()
        controller?.applyTriggerPreferences()
    }

    @objc func toggleDisplayTrigger() {
        Prefs.revealOnDisplayChange.toggle()
        controller?.applyTriggerPreferences()
    }

    @objc func toggleHoverToReveal() {
        Prefs.hoverToReveal.toggle()
        controller?.applyHoverPreference()
    }

    @objc func toggleSlimMode() {
        Prefs.slimMode.toggle()
        controller?.refreshSizing()
    }

    @objc func toggleHotkey() {
        Prefs.hotkeyEnabled.toggle()
        controller?.applyHotkeyPreference()
        if Prefs.hotkeyEnabled && !HotKey.shared.isRegistered {
            let alert = NSAlert()
            alert.messageText = "Another app already uses \(HotKey.displayName)"
            alert.informativeText =
                "Quit the app that owns the shortcut, or leave this turned off "
                + "and click the chevron instead."
            alert.alertStyle = .warning
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    @objc func toggleLaunchAtLogin() {
        do {
            if launchAtLoginEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't change the Open at Login setting"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }
}
