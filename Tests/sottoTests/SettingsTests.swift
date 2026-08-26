import Cocoa
import Foundation
import Testing

@testable import sotto

/// `Settings` reads and writes process-wide state, so these run one at a time
/// against a throwaway suite rather than the user's real defaults.
@Suite("Settings", .serialized)
struct SettingsTests {

    private func withScratchDefaults(_ body: (UserDefaults) throws -> Void) rethrows {
        let name = "sotto.tests.\(UUID().uuidString)"
        let scratch = UserDefaults(suiteName: name)!
        let original = Settings.defaults
        Settings.defaults = scratch
        defer {
            Settings.defaults = original
            UserDefaults.standard.removePersistentDomain(forName: name)
        }
        try body(scratch)
    }

    // MARK: - key

    /// Absent means "never chosen" and must fall back; nil means "deliberately
    /// unbound" and must stay unbound.
    @Test func absentKeyFallsBackToTheDefault() throws {
        try withScratchDefaults { _ in
            #expect(Settings.key == .defaultToggle)
        }
    }

    @Test func unbindingIsRemembered() throws {
        try withScratchDefaults { _ in
            Settings.key = nil
            #expect(Settings.key == nil)
        }
    }

    @Test func rebindingAfterUnbindingClearsTheUnboundFlag() throws {
        try withScratchDefaults { _ in
            Settings.key = nil
            let combo = KeyCombo(keyCode: 49, modifiers: NSEvent.ModifierFlags.control.rawValue)
            Settings.key = combo
            #expect(Settings.key == combo)
        }
    }

    @Test func storedKeyRoundTrips() throws {
        try withScratchDefaults { _ in
            let combo = KeyCombo(keyCode: 96, modifiers: 0)
            Settings.key = combo
            #expect(Settings.key == combo)
        }
    }

    @Test func corruptStoredKeyFallsBackToTheDefault() throws {
        try withScratchDefaults { scratch in
            scratch.set(Data("not json".utf8), forKey: "key")
            #expect(Settings.key == .defaultToggle)
        }
    }

    // MARK: - mode

    @Test func modeDefaultsToToggle() throws {
        try withScratchDefaults { _ in
            #expect(Settings.mode == .toggle)
        }
    }

    /// Push-to-talk is built but not shipped. A build that once wrote "hold"
    /// must not resurrect it.
    @Test func unshippedModeIsNotRestored() throws {
        try withScratchDefaults { scratch in
            scratch.set(TriggerMode.hold.rawValue, forKey: "mode")
            #expect(Settings.mode == .toggle)
        }
    }

    @Test func unknownModeFallsBackToToggle() throws {
        try withScratchDefaults { scratch in
            scratch.set("nonsense", forKey: "mode")
            #expect(Settings.mode == .toggle)
        }
    }

    @Test func selectableModeRoundTrips() throws {
        try withScratchDefaults { _ in
            Settings.mode = .toggle
            #expect(Settings.mode == .toggle)
        }
    }

    // MARK: - showHUD

    @Test func hudIsOnUntilTurnedOff() throws {
        try withScratchDefaults { _ in
            #expect(Settings.showHUD)
            Settings.showHUD = false
            #expect(!Settings.showHUD)
            Settings.showHUD = true
            #expect(Settings.showHUD)
        }
    }
}

@Suite("TriggerMode")
struct TriggerModeTests {

    /// Raw values are the on-disk representation.
    @Test func rawValuesAreStable() {
        #expect(TriggerMode.toggle.rawValue == "toggle")
        #expect(TriggerMode.hold.rawValue == "hold")
        #expect(TriggerMode(rawValue: "toggle") == .toggle)
    }

    @Test func onlyToggleIsSelectable() {
        #expect(TriggerMode.selectable == [.toggle])
        #expect(!TriggerMode.selectable.contains(.hold))
    }

    @Test func idMatchesRawValue() {
        for mode in TriggerMode.allCases {
            #expect(mode.id == mode.rawValue)
        }
    }

    @Test func labelsAreDistinct() {
        #expect(TriggerMode.toggle.label == "Mute / unmute")
        #expect(TriggerMode.hold.label == "Push to talk")
    }
}
