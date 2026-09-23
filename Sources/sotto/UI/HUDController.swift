import SwiftUI

/// Brief on-screen confirmation for deliberate toggles. Hold transitions
/// deliberately do not show it — during push-to-talk it would flash constantly.
@MainActor
final class HUDController {
    private var panel: NSPanel?

    private let visibleDuration: TimeInterval = 1.8

    /// A fresh panel per toggle: a fade still running from the previous one
    /// then operates on its own, already hidden window instead of this one.
    /// `sticky` keeps it on screen until `hide()` — used while a push-to-talk
    /// key is held down.
    func show(muted: Bool, device: String, sticky: Bool = false) {
        panel?.orderOut(nil)

        let panel = makePanel(muted: muted, device: device)
        self.panel = panel
        panel.orderFrontRegardless()

        guard !sticky else { return }

        // Release the panel once hidden: an ordered-out window still renders
        // the ripple's repeatForever animation every frame (~8% CPU forever).
        DispatchQueue.main.asyncAfter(deadline: .now() + visibleDuration) { [weak self] in
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.35
                panel.animator().alphaValue = 0
            } completionHandler: {
                panel.orderOut(nil)
                MainActor.assumeIsolated {
                    if self?.panel === panel { self?.panel = nil }
                }
            }
        }
    }

    func hide() {
        guard let panel else { return }
        self.panel = nil
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            panel.animator().alphaValue = 0
        } completionHandler: {
            panel.orderOut(nil)
        }
    }

    private func makePanel(muted: Bool, device: String) -> NSPanel {
        let hosting = NSHostingController(rootView: HUDView(muted: muted, device: device))
        hosting.sizingOptions = .preferredContentSize
        let size = hosting.view.fittingSize

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
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

        // Assigning the content view controller collapses the frame to zero
        // until the next layout pass, so center on the measured size instead.
        // The screen under the cursor is where the user is looking;
        // `NSScreen.main` is just the primary display for an accessory app.
        let mouse = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main {
            panel.setFrameOrigin(NSPoint(
                x: screen.frame.midX - size.width / 2,
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
                Text(muted ? "muted" : "unmuted")
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
