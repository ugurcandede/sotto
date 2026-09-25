import SwiftUI

struct UpdateBanner: View {
    let update: AppUpdate
    @ObservedObject var viewModel: MenuBarViewModel

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.down.circle.fill")
            Text(title)
                .fontWeight(.medium)
            Spacer()
            switch viewModel.updateState {
            case .idle:
                Button("update") { viewModel.performUpdate() }
                    .buttonStyle(.plain)
                    .help("Install v\(update.version) and relaunch")
            case .updating:
                ProgressView()
                    .controlSize(.mini)
            case .notInBrewYet:
                Button("retry") { viewModel.performUpdate() }
                    .buttonStyle(.plain)
                    .help("Homebrew gets new versions a few minutes after the release")
            case .failed:
                Button("log") { viewModel.openUpdateLog() }
                    .buttonStyle(.plain)
                    .help("Show what brew reported")
                Button("retry") { viewModel.performUpdate() }
                    .buttonStyle(.plain)
            }
            if viewModel.updateState != .updating {
                Button {
                    viewModel.dismissUpdate()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .medium))
                }
                .buttonStyle(.plain)
                .help("Hide until the next version")
            }
        }
        .font(.system(size: 11))
        .foregroundColor(viewModel.updateState == .failed ? .orange : .accentColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background((viewModel.updateState == .failed ? Color.orange : Color.accentColor).opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal, 10)
        .padding(.top, 10)
    }

    private var title: String {
        switch viewModel.updateState {
        case .idle: "v\(update.version) available"
        case .updating: "updating to v\(update.version)…"
        case .notInBrewYet: "not in Homebrew yet"
        case .failed: "update failed"
        }
    }
}
