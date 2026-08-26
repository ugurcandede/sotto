import Carbon.HIToolbox
import Foundation

/// Global toggle shortcut. `RegisterEventHotKey` needs no permission — that is
/// the whole reason toggle mode works out of the box.
final class ToggleHotkey {
    var onTrigger: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private static let signature = OSType(0x484D4943) // 'HMIC'

    /// Carbon's C callback can't capture Swift context, so it reaches the one
    /// live instance through this static bridge.
    private static weak var shared: ToggleHotkey?

    @discardableResult
    func register(_ combo: KeyCombo) -> Bool {
        unregister()
        installHandlerIfNeeded()

        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: ToggleHotkey.signature, id: 1)
        let status = RegisterEventHotKey(
            UInt32(combo.keyCode), combo.carbonModifiers, hotKeyID,
            GetApplicationEventTarget(), 0, &ref
        )

        guard status == noErr, let ref else { return false }
        hotKeyRef = ref
        ToggleHotkey.shared = self
        return true
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
    }

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ -> OSStatus in
            ToggleHotkey.shared?.onTrigger?()
            return noErr
        }, 1, &type, nil, &eventHandler)
    }

    deinit { unregister() }
}
