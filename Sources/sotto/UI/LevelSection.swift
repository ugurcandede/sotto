import SwiftUI

struct LevelSection: View {
    @ObservedObject var meter: LevelMeter
    let muted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Button(meter.isRunning ? "Stop" : "Test") {
                    meter.start()
                }
                .controlSize(.small)
                .frame(width: 54)

                LevelBar(level: meter.level)
            }

            if meter.accessDenied {
                Text("Microphone access denied — grant it in System Settings > Privacy & Security > Microphone.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            } else if meter.isRunning && muted {
                Text("Muted — unmute to see input level.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct LevelBar: View {
    let level: Float

    private let segments = 16

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<segments, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(isLit(index) ? color(index) : Color.secondary.opacity(0.18))
                    .frame(height: 9)
            }
        }
        .animation(.linear(duration: 0.06), value: level)
    }

    private func isLit(_ index: Int) -> Bool {
        Float(index) / Float(segments) < level
    }

    private func color(_ index: Int) -> Color {
        if index >= segments - 2 { return .red }
        if index >= segments - 5 { return .yellow }
        return .green
    }
}
