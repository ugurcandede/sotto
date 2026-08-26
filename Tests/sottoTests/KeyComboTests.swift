import Carbon.HIToolbox
import Cocoa
import Testing

@testable import sotto

@Suite("ModifierKey")
struct ModifierKeyTests {

    @Test func keyCodesRoundTrip() {
        for modifier in ModifierKey.allCases {
            #expect(ModifierKey(keyCode: modifier.keyCode) == modifier)
        }
    }

    @Test func unknownKeyCodeIsNotAModifier() {
        #expect(ModifierKey(keyCode: 46) == nil)
    }

    /// Hold detection tells left from right purely by this mask, so a duplicate
    /// would silently fire the wrong side.
    @Test func deviceMasksAreDistinct() {
        let masks = Set(ModifierKey.allCases.map(\.deviceMask))
        #expect(masks.count == ModifierKey.allCases.count)
    }

    @Test func keyCodesAreDistinct() {
        let codes = Set(ModifierKey.allCases.map(\.keyCode))
        #expect(codes.count == ModifierKey.allCases.count)
    }

    @Test func labelsNameTheSide() {
        #expect(ModifierKey.rightOption.label == "Right ⌥")
        #expect(ModifierKey.leftShift.label == "Left ⇧")
    }
}

@Suite("KeyCombo")
struct KeyComboTests {

    // MARK: - Classification

    @Test func modifierComboReportsItsDeviceMask() {
        let combo = KeyCombo(keyCode: ModifierKey.rightOption.keyCode, modifiers: 0)
        #expect(combo.isModifierKey)
        #expect(combo.deviceMask == ModifierKey.rightOption.deviceMask)
    }

    @Test func plainKeyHasNoDeviceMask() {
        let combo = KeyCombo(keyCode: 46, modifiers: 0)
        #expect(!combo.isModifierKey)
        #expect(combo.deviceMask == nil)
    }

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

    @Test func modifierCombosDisplayTheirSide() {
        #expect(KeyCombo(keyCode: ModifierKey.rightOption.keyCode, modifiers: 0).display == "Right ⌥")
    }

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
        #expect(!KeyCombo(keyCode: 46, modifiers: 0).isBindable(allowingBareModifier: false))
        #expect(!KeyCombo(keyCode: 46, modifiers: 0).isBindable(allowingBareModifier: true))
    }

    @Test func anyModifierMakesAKeyBindable() {
        let combo = KeyCombo(keyCode: 46, modifiers: NSEvent.ModifierFlags.shift.rawValue)
        #expect(combo.isBindable(allowingBareModifier: false))
    }

    @Test func functionKeysAreBindableOnTheirOwn() {
        #expect(KeyCombo(keyCode: 96, modifiers: 0).isBindable(allowingBareModifier: false))
        #expect(DictationKey.combo.isBindable(allowingBareModifier: false))
    }

    /// Hold mode is the only place a naked modifier is a usable binding.
    @Test func bareModifierNeedsHoldMode() {
        #expect(KeyCombo.defaultHold.isBindable(allowingBareModifier: true))
        #expect(!KeyCombo.defaultHold.isBindable(allowingBareModifier: false))
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

    @Test func defaultHoldIsABareRightOption() {
        #expect(KeyCombo.defaultHold.isModifierKey)
        #expect(KeyCombo.defaultHold.modifiers == 0)
        #expect(KeyCombo.defaultHold.deviceMask == ModifierKey.rightOption.deviceMask)
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
