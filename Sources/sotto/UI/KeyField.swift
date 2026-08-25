import SwiftUI

/// A key assignment: record any shortcut, or pick the microphone key. Choosing
/// the mic key is what installs the HID remap, so it belongs here rather than
/// in a setting of its own.
struct KeyField: View {
    @Binding var combo: KeyCombo?
    var allowsBareModifier = false

    @State private var recording = false
    @State private var monitor: Any?

    /// Bare F-keys reach us only as system events on Macs whose function row is
    /// in media mode, so spell out what actually records.
    static let hint = "Records ⌘⌥⌃⇧ + key, fn + F1–F12, or the 🎤 key."

    var body: some View {
        Menu {
            Button("Record shortcut…") { start() }
            Button("🎤 Mic key (F5)") {
                stop()
                combo = DictationKey.combo
            }
            Divider()
            Button("None") {
                stop()
                combo = nil
            }
        } label: {
            Text(recording ? "Press keys…" : label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
        }
        .menuStyle(.borderlessButton)
        .frame(width: 96)
        .onDisappear(perform: stop)
    }

    private var label: String {
        guard let combo else { return "None" }
        return combo == DictationKey.combo ? "🎤 F5" : combo.display
    }

    private func start() {
        // The local monitor only sees events routed to a key window.
        NSApp.activate(ignoringOtherApps: true)
        NSApp.keyWindow?.makeFirstResponder(nil)
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            handle(event) ? nil : event
        }
    }

    private func stop() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    /// Returns true when the event was consumed.
    private func handle(_ event: NSEvent) -> Bool {
        if event.type == .flagsChanged {
            guard allowsBareModifier,
                  let modifier = ModifierKey(keyCode: UInt16(event.keyCode)),
                  UInt64(event.modifierFlags.rawValue) & modifier.deviceMask != 0
            else { return false }

            combo = KeyCombo(keyCode: modifier.keyCode, modifiers: 0)
            stop()
            return true
        }

        if event.keyCode == 53 { // esc cancels
            stop()
            return true
        }

        let candidate = KeyCombo(event: event)
        let usable = !candidate.flags.isEmpty || candidate.isFunctionKey || allowsBareModifier
        guard usable else { return true }   // a bare letter would eat typing
        combo = candidate
        stop()
        return true
    }
}
