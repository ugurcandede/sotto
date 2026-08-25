/// What the bound key does. Toggle flips the state and stays there;
/// push-to-talk inverts it only while the key is down.
enum TriggerMode: String, CaseIterable, Identifiable {
    case toggle, hold

    var id: String { rawValue }

    /// Push-to-talk is built but not shipped yet: it needs an event tap, and
    /// Input Monitoring can't be granted reliably to an ad-hoc signed build.
    static let selectable: [TriggerMode] = [.toggle]

    var label: String {
        switch self {
        case .toggle: "Mute / unmute"
        case .hold: "Push to talk"
        }
    }
}
