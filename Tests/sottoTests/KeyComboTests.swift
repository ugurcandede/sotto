import Carbon.HIToolbox
import Cocoa
import Testing

@testable import sotto

@Suite("KeyCombo")
struct KeyComboTests {

    // MARK: - Classification

    @Test(arguments: [
        UInt16(122), 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111,
        105, 107, 113, 106, 64, 79, 80, 90,
    ])
    func functionKeysStandAlone(_ keyCode: UInt16) {
        #expect(KeyCombo(keyCode: keyCode, modifiers: 0).isFunctionKey)
    }

    @Test func letterIsNotAFunctionKey() {
        #expect(!KeyCombo(keyCode: 46, modifiers: 0).isFunctionKey)
    }

    // MARK: - Carbon translation

    @Test func carbonModifiersMapEachFlag() {
        func carbon(_ flags: NSEvent.ModifierFlags) -> UInt32 {
            KeyCombo(keyCode: 46, modifiers: flags.rawValue).carbonModifiers
        }
        #expect(carbon(.command) == UInt32(cmdKey))
        #expect(carbon(.option) == UInt32(optionKey))
        #expect(carbon(.control) == UInt32(controlKey))
        #expect(carbon(.shift) == UInt32(shiftKey))
        #expect(carbon([]) == 0)
        #expect(carbon([.command, .shift]) == UInt32(cmdKey) | UInt32(shiftKey))
    }

    /// A stray non-modifier bit must not leak into the Carbon registration.
    @Test func carbonModifiersIgnoreUnrelatedFlags() {
        let combo = KeyCombo(keyCode: 46, modifiers: NSEvent.ModifierFlags.capsLock.rawValue)
        #expect(combo.carbonModifiers == 0)
    }

    // MARK: - Display

    @Test func modifiersRenderInMacOrder() {
        let all = NSEvent.ModifierFlags([.command, .option, .control, .shift]).rawValue
        #expect(KeyCombo(keyCode: 49, modifiers: all).display == "⌃⌥⇧⌘Space")
    }

    @Test(arguments: [
        (UInt16(49), "Space"), (36, "↩"), (48, "⇥"), (51, "⌫"), (53, "⎋"),
        (123, "←"), (124, "→"), (125, "↓"), (126, "↑"),
        (96, "F5"), (105, "F13"), (90, "F20"),
    ])
    func namedKeysHaveStableLabels(_ keyCode: UInt16, _ expected: String) {
        #expect(KeyCombo.keyName(keyCode) == expected)
    }

    /// Unnamed keys resolve against the active keyboard layout, which varies by
    /// machine — only the fallback shape is guaranteed.
    @Test func unnamedKeyStillProducesALabel() {
        #expect(!KeyCombo.keyName(46).isEmpty)
    }

    // MARK: - Bindability

    /// Binding a bare letter would swallow every keystroke that follows.
    @Test func bareLetterIsNotBindable() {
        #expect(!KeyCombo(keyCode: 46, modifiers: 0).isBindable)
    }

    @Test func anyModifierMakesAKeyBindable() {
        let combo = KeyCombo(keyCode: 46, modifiers: NSEvent.ModifierFlags.shift.rawValue)
        #expect(combo.isBindable)
    }

    @Test func functionKeysAreBindableOnTheirOwn() {
        #expect(KeyCombo(keyCode: 96, modifiers: 0).isBindable)
        #expect(DictationKey.combo.isBindable)
    }

    // MARK: - Capture from an event

    private func keyDown(_ keyCode: UInt16, _ flags: NSEvent.ModifierFlags) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: flags,
            timestamp: 0, windowNumber: 0, context: nil,
            characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: keyCode
        )!
    }

    @Test func captureKeepsTheFourRealModifiers() {
        let combo = KeyCombo(event: keyDown(46, [.command, .option, .control, .shift]))
        #expect(combo.keyCode == 46)
        #expect(combo.flags == [.command, .option, .control, .shift])
    }

    /// Caps lock and fn ride along on real events. Storing them would make the
    /// combo unmatchable, since the hotkey never sees them set the same way.
    @Test func captureDropsCapsLockAndFunction() {
        let combo = KeyCombo(event: keyDown(46, [.command, .capsLock, .function, .numericPad]))
        #expect(combo.flags == [.command])
    }

    @Test func captureOfABareKeyHasNoModifiers() {
        #expect(KeyCombo(event: keyDown(96, [])).flags.isEmpty)
    }

    @Test func captureSurvivesARoundTripThroughStorage() throws {
        let combo = KeyCombo(event: keyDown(49, [.control, .shift, .capsLock]))
        let data = try JSONEncoder().encode(combo)
        #expect(try JSONDecoder().decode(KeyCombo.self, from: data) == combo)
    }

    // MARK: - Persistence

    @Test func codableRoundTrip() throws {
        let combo = KeyCombo(keyCode: 46, modifiers: NSEvent.ModifierFlags([.command, .option]).rawValue)
        let data = try JSONEncoder().encode(combo)
        #expect(try JSONDecoder().decode(KeyCombo.self, from: data) == combo)
    }

    // MARK: - Defaults

    @Test func defaultToggleIsOptionCommandM() {
        #expect(KeyCombo.defaultToggle.keyCode == 46)
        #expect(KeyCombo.defaultToggle.flags.contains(.command))
        #expect(KeyCombo.defaultToggle.flags.contains(.option))
        #expect(!KeyCombo.defaultToggle.flags.contains(.shift))
        #expect(!KeyCombo.defaultToggle.flags.contains(.control))
    }
}

@Suite("DictationKey")
struct DictationKeyTests {

    /// The remap lands on F13 and the rest of the app recognises the mic key by
    /// comparing against exactly this combo.
    @Test func comboIsBareF13() {
        #expect(DictationKey.combo == KeyCombo(keyCode: 105, modifiers: 0))
        #expect(KeyCombo.keyName(DictationKey.keyCode) == "F13")
        #expect(DictationKey.combo.isFunctionKey)
    }

    @Test func remapEndpointsAreTheDocumentedUsages() {
        #expect(DictationKey.source == 0xC000000CF)
        #expect(DictationKey.destination == 0x700000068)
    }
}
