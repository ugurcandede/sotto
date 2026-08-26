import SwiftUI

/// The menu bar glyph. SwiftUI rather than `NSImage` because `symbolEffect`
/// only exists on the SwiftUI side.
struct StatusIcon: View {
    @ObservedObject var viewModel: MenuBarViewModel

    private var symbolName: String {
        if !viewModel.deviceSupported { return "mic.badge.xmark" }
        if viewModel.mode == .hold { return viewModel.muted ? "mic.slash.circle" : "mic.circle" }
        return viewModel.muted ? "mic.slash" : "mic"
    }

    private var color: Color {
        if viewModel.muted { return .red }
        return viewModel.holdActive ? .accentColor : .primary
    }

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(color)
            .contentTransition(.symbolEffect(.replace.downUp))
            .symbolEffect(.pulse, options: .repeat(2), value: viewModel.pulseTrigger)
            .frame(width: 18, height: 22)
            .accessibilityLabel(viewModel.muted ? "Microphone muted" : "Microphone unmuted")
    }
}

/// Clicks must reach the status item button underneath, not this overlay.
final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
