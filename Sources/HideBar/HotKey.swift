import AppKit
import Carbon.HIToolbox

/// One global keyboard shortcut, registered through Carbon.
///
/// Carbon hot keys need no Accessibility permission. A keyboard
/// `NSEvent.addGlobalMonitorForEvents` would need one, which is why it is not
/// used here — many people cannot grant that permission on a managed Mac.
final class HotKey {
    static let shared = HotKey()
    private init() {}

    /// Control-Option-Command-B. Chosen because macOS and common apps leave it free.
    static let keyCode = UInt32(kVK_ANSI_B)
    static let modifiers = UInt32(controlKey | optionKey | cmdKey)
    static let displayName = "⌃⌥⌘B"

    private static let signature: OSType = 0x48444B59   // 'HDKY'
    private static let identifier: UInt32 = 1

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    fileprivate var onPress: (() -> Void)?

    var isRegistered: Bool { hotKeyRef != nil }

    /// Returns false when another app already owns the shortcut.
    @discardableResult
    func register(action: @escaping () -> Void) -> Bool {
        guard hotKeyRef == nil else { return true }
        onPress = action

        if eventHandler == nil {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                     eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), hotKeyEventHandler,
                                1, &spec, nil, &eventHandler)
        }

        let id = EventHotKeyID(signature: Self.signature, id: Self.identifier)
        let status = RegisterEventHotKey(Self.keyCode, Self.modifiers, id,
                                         GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr {
            hotKeyRef = nil
            return false
        }
        return true
    }

    func unregister() {
        guard let ref = hotKeyRef else { return }
        UnregisterEventHotKey(ref)
        hotKeyRef = nil
    }
}

/// C callback. It captures nothing, so it may cross into Carbon safely.
private let hotKeyEventHandler: EventHandlerUPP = { _, event, _ -> OSStatus in
    var id = EventHotKeyID()
    GetEventParameter(event, EventParamName(kEventParamDirectObject),
                      EventParamType(typeEventHotKeyID), nil,
                      MemoryLayout<EventHotKeyID>.size, nil, &id)
    if id.id == 1 {
        DispatchQueue.main.async { HotKey.shared.onPress?() }
    }
    return noErr
}
