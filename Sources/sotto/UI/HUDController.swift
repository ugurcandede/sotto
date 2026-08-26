import SwiftUI

/// Brief on-screen confirmation for deliberate toggles.
@MainActor
final class HUDController {
    private var panel: NSPanel?

    private let visibleDuration: TimeInterval = 1.8

    /// A fresh panel per toggle: a fade still running from the previous one
    /// then operates on its own, already hidden window instead of this one.
    func show(muted: Bool, device: String) {
        panel?.orderOut(nil)

        let panel = makePanel(muted: muted, device: device)
        self.panel = panel
        panel.orderFrontRegardless()

        DispatchQueue.main.asyncAfter(deadline: .now() + visibleDuration) {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.35
                panel.animator().alphaValue = 0
            } completionHandler: {
                panel.orderOut(nil)
            }
        }
    }

    private func makePanel(muted: Bool, device: String) -> NSPanel {
        let hosting = NSHostingController(rootView: HUDView(muted: muted, device: device))
        hosting.sizingOptions = .preferredContentSize

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: hosting.view.fittingSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hosting
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        if let screen = NSScreen.main {
            panel.setFrameOrigin(NSPoint(
                x: screen.frame.midX - panel.frame.width / 2,
                y: screen.visibleFrame.minY + 120
            ))
        }
        return panel
    }
}

private struct HUDView: View {
    let muted: Bool
    let device: String

    @State private var rippling = false

    private var tint: Color { muted ? .red : .green }

    var body: some View {
        HStack(spacing: 12) {
            icon
            VStack(alignment: .leading, spacing: 1) {
                Text(muted ? "Muted" : "Unmuted")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Text(device)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08)))
        .onAppear { rippling = true }
    }

    /// Concentric rings pulsing out of the glyph, like the low-battery HUD.
    private var icon: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(tint.opacity(0.45), lineWidth: 1.5)
                    .frame(width: 30, height: 30)
                    .scaleEffect(rippling ? 1.9 : 0.65)
                    .opacity(rippling ? 0 : 0.7)
                    .animation(
                        .easeOut(duration: 1.5)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.5),
                        value: rippling
                    )
            }

            Circle()
                .fill(tint.opacity(0.18))
                .frame(width: 30, height: 30)

            Image(systemName: muted ? "mic.slash.fill" : "mic.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: 34, height: 34)
    }
}
