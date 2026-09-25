import SwiftUI

struct UpdateBanner: View {
    let update: AppUpdate
    @ObservedObject var viewModel: MenuBarViewModel
    @State private var copied = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.down.circle.fill")
            Text("v\(update.version) available")
                .fontWeight(.medium)
            Spacer()
            Button("notes") { viewModel.openUpdateNotes() }
                .buttonStyle(.plain)
                .help("Open the release notes")
            Button(copied ? "copied" : "copy brew") {
                viewModel.copyBrewCommand()
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
            }
            .buttonStyle(.plain)
            .help(UpdateChecker.brewCommand)
            Button {
                viewModel.dismissUpdate()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .medium))
            }
            .buttonStyle(.plain)
            .help("Hide until the next version")
        }
        .font(.system(size: 11))
        .foregroundColor(.accentColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal, 10)
        .padding(.top, 10)
    }
}
