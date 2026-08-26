import Carbon.HIToolbox
import Cocoa

struct KeyCombo: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: UInt

    var flags: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifiers) }

    init(keyCode: UInt16, modifiers: UInt) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    init(event: NSEvent) {
        keyCode = UInt16(event.keyCode)
        modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            .intersection([.command, .option, .control, .shift]).rawValue
    }

    /// Function keys are usable on their own; a bare letter would swallow
    /// typing, so those need a modifier.
    var isFunctionKey: Bool { KeyCombo.functionKeys.contains(keyCode) }

    /// A bare letter would swallow typing, so it needs a modifier. Function
    /// keys stand alone.
    var isBindable: Bool { !flags.isEmpty || isFunctionKey }

    private static let functionKeys: Set<UInt16> = [
        122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111,
        105, 107, 113, 106, 64, 79, 80, 90,
    ]

    var carbonModifiers: UInt32 {
        var value: UInt32 = 0
        if flags.contains(.command) { value |= UInt32(cmdKey) }
        if flags.contains(.option) { value |= UInt32(optionKey) }
        if flags.contains(.control) { value |= UInt32(controlKey) }
        if flags.contains(.shift) { value |= UInt32(shiftKey) }
        return value
    }

    var display: String {
        var text = ""
        if flags.contains(.control) { text += "⌃" }
        if flags.contains(.option) { text += "⌥" }
        if flags.contains(.shift) { text += "⇧" }
        if flags.contains(.command) { text += "⌘" }
        return text + KeyCombo.keyName(keyCode)
    }

    static let defaultToggle = KeyCombo(keyCode: 46, modifiers: NSEvent.ModifierFlags([.command, .option]).rawValue) // ⌥⌘M

    private static let namedKeys: [UInt16: String] = [
        49: "Space", 36: "↩", 48: "⇥", 51: "⌫", 53: "⎋",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        105: "F13", 107: "F14", 113: "F15", 106: "F16", 64: "F17", 79: "F18", 80: "F19", 90: "F20",
    ]

    static func keyName(_ keyCode: UInt16) -> String {
        if let named = namedKeys[keyCode] { return named }
        return character(for: keyCode)?.uppercased() ?? "Key \(keyCode)"
    }

    /// Resolves the key code against the active keyboard layout so a QWERTZ or
    /// AZERTY user sees the label printed on their key.
    private static func character(for keyCode: UInt16) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }

        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)

        let status = data.withUnsafeBytes { buffer -> OSStatus in
            guard let layout = buffer.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return -1 }
            return UCKeyTranslate(
                layout, keyCode, UInt16(kUCKeyActionDisplay), 0,
                UInt32(LMGetKbdType()), UInt32(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState, characters.count, &length, &characters
            )
        }
        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: characters, count: length)
    }
}
