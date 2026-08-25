import Carbon.HIToolbox
import Foundation

/// Global toggle shortcut. `RegisterEventHotKey` needs no permission — that is
/// the whole reason toggle mode works out of the box.
final class ToggleHotkey {
    var onTrigger: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private static let signature = OSType(0x484D4943) // 'HMIC'

    private static var instances: [UInt32: ToggleHotkey] = [:]
    private static var nextID: UInt32 = 1

    private var id: UInt32?

    @discardableResult
    func register(_ combo: KeyCombo) -> Bool {
        unregister()
        installHandlerIfNeeded()

        let id = ToggleHotkey.nextID
        ToggleHotkey.nextID += 1

        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: ToggleHotkey.signature, id: id)
        let status = RegisterEventHotKey(
            UInt32(combo.keyCode), combo.carbonModifiers, hotKeyID,
            GetApplicationEventTarget(), 0, &ref
        )

        guard status == noErr, let ref else { return false }
        hotKeyRef = ref
        self.id = id
        ToggleHotkey.instances[id] = self
        return true
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
        if let id { ToggleHotkey.instances.removeValue(forKey: id) }
        id = nil
    }

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID
            )
            guard status == noErr else { return status }
            ToggleHotkey.instances[hotKeyID.id]?.onTrigger?()
            return noErr
        }, 1, &type, nil, &eventHandler)
    }

    deinit { unregister() }
}
