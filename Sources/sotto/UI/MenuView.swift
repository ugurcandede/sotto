import SwiftUI

struct MenuView: View {
    @ObservedObject var viewModel: MenuBarViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            section("Input") { inputSection }
            Divider()
            section("Keys") { keysSection }
            Divider()
            section("General") { generalSection }
            Divider()
            AboutSection()
            Divider()
            quitButton
        }
        .frame(width: 268)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title.lowercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.7))
                .tracking(0.6)
            content()
        }
        .font(.system(size: 12))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: viewModel.muted ? "mic.slash.fill" : "mic.fill")
                .font(.system(size: 20))
                .foregroundStyle(viewModel.muted ? Color.red : Color.accentColor)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text(viewModel.statusText)
                    .font(.system(size: 13, weight: .semibold))
                Text(viewModel.deviceSupported ? viewModel.strategyName : "device can't be muted")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if viewModel.mode != .hold {
                Button(viewModel.muted ? "unmute" : "mute") {
                    viewModel.toggle()
                }
                .controlSize(.small)
                .disabled(!viewModel.deviceSupported)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("device")
                Spacer()
                Picker("", selection: Binding(
                    get: { viewModel.selectedInput },
                    set: { viewModel.selectInput($0) }
                )) {
                    ForEach(viewModel.inputs) { Text($0.name).tag($0.id) }
                }
                .labelsHidden()
                .frame(maxWidth: 170)
            }

            if let warning = viewModel.switchWarning {
                note(warning)
            }

            HStack(spacing: 7) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Slider(value: Binding(
                    get: { Double(viewModel.inputVolume) },
                    set: { viewModel.setVolume(Float($0)) }
                ), in: 0...1)
                .controlSize(.mini)
                .disabled(!viewModel.canAdjustVolume)
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            LevelSection(meter: viewModel.levelMeter, muted: viewModel.muted)
        }
    }

    private var keysSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if TriggerMode.selectable.count > 1 {
                HStack {
                    Text("mode")
                    Spacer()
                    Picker("", selection: $viewModel.mode) {
                        ForEach(TriggerMode.selectable) { Text($0.label).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 130)
                }
            }

            HStack {
                Text("key")
                Spacer()
                KeyField(combo: $viewModel.key, allowsBareModifier: viewModel.mode == .hold)
            }

            note(KeyField.hint)

            if viewModel.needsAccessibility {
                permissionNotice
            } else if viewModel.mode == .hold {
                note(viewModel.baseMuted
                     ? "hold \(viewModel.keyLabel) to talk."
                     : "hold \(viewModel.keyLabel) to mute.")
            }

            if viewModel.usesMicKey {
                note("Dictation stays off while sotto owns the 🎤 key.")
            }
        }
    }

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("show on-screen feedback", isOn: $viewModel.showHUD)
                .toggleStyle(.checkbox)

            Toggle("launch at login", isOn: $viewModel.launchAtLogin)
                .toggleStyle(.checkbox)
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var permissionNotice: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Accessibility permission is required for push to talk.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Button("open System Settings") {
                viewModel.openAccessibilitySettings()
            }
            .controlSize(.small)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.orange.opacity(0.12)))
    }

    private var quitButton: some View {
        Button {
            NSApp.terminate(nil)
        } label: {
            Text("quit sotto")
                .font(.system(size: 12))
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}
