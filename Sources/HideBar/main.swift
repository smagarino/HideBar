import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = StatusBarController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)   // no Dock icon, no menu bar app menu
        controller.install()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
