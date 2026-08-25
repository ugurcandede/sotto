import SwiftUI

struct AboutSection: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ".dev"
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Text("Built with")
                    .foregroundColor(.secondary.opacity(0.5))
                Text("❤️")
                    .font(.system(size: 9))
                Text("for")
                    .foregroundColor(.secondary.opacity(0.5))
                Image(systemName: "waveform")
                    .foregroundColor(.secondary.opacity(0.5))
                Text("people who talk")
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .font(.system(size: 10))

            HStack(spacing: 5) {
                Link(destination: URL(string: "https://github.com/ugurcandede")!) {
                    Text("ugurcandede")
                        .font(.system(size: 10, weight: .medium))
                }

                Text("·")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.3))

                Link(destination: URL(string: "https://ugurcandede.github.io/sotto")!) {
                    HStack(spacing: 3) {
                        Image(systemName: "tag")
                            .font(.system(size: 8))
                        Text("v\(version)")
                            .font(.system(size: 10))
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}
