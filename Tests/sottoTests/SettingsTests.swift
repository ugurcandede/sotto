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
    @Test func absentKeyFallsBackToTheDefault() {
        withScratchDefaults { _ in
            #expect(Settings.key == .defaultToggle)
        }
    }

    @Test func unbindingIsRemembered() {
        withScratchDefaults { _ in
            Settings.key = nil
            #expect(Settings.key == nil)
        }
    }

    @Test func rebindingAfterUnbindingClearsTheUnboundFlag() {
        withScratchDefaults { _ in
            Settings.key = nil
            let combo = KeyCombo(keyCode: 49, modifiers: NSEvent.ModifierFlags.control.rawValue)
            Settings.key = combo
            #expect(Settings.key == combo)
        }
    }

    @Test func storedKeyRoundTrips() {
        withScratchDefaults { _ in
            let combo = KeyCombo(keyCode: 96, modifiers: 0)
            Settings.key = combo
            #expect(Settings.key == combo)
        }
    }

    @Test func corruptStoredKeyFallsBackToTheDefault() {
        withScratchDefaults { scratch in
            scratch.set(Data("not json".utf8), forKey: "key")
            #expect(Settings.key == .defaultToggle)
        }
    }

    // MARK: - showHUD

    @Test func hudIsOnUntilTurnedOff() {
        withScratchDefaults { _ in
            #expect(Settings.showHUD)
            Settings.showHUD = false
            #expect(!Settings.showHUD)
            Settings.showHUD = true
            #expect(Settings.showHUD)
        }
    }
}
