/// What the bound key does. Toggle flips the state and stays there;
/// push-to-talk inverts it only while the key is down.
enum TriggerMode: String, CaseIterable, Identifiable {
    case toggle, hold

    var id: String { rawValue }

    static let selectable: [TriggerMode] = allCases

    var label: String {
        switch self {
        case .toggle: "mute / unmute"
        case .hold: "Push to talk"
        }
    }
}
