import Foundation

enum Settings {
    /// The app always uses the standard suite; tests swap in a throwaway one.
    static var defaults = UserDefaults.standard

    /// nil means no key is bound; absent means "never set", so fall back to the
    /// default shortcut.
    static var key: KeyCombo? {
        get {
            if defaults.bool(forKey: "keyUnbound") { return nil }
            return decode("key") ?? .defaultToggle
        }
        set {
            defaults.set(newValue == nil, forKey: "keyUnbound")
            if let newValue { encode(newValue, "key") }
        }
    }

    static var showHUD: Bool {
        get { defaults.object(forKey: "showHUD") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showHUD") }
    }

    private static func decode(_ key: String) -> KeyCombo? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(KeyCombo.self, from: data)
    }

    private static func encode(_ combo: KeyCombo, _ key: String) {
        guard let data = try? JSONEncoder().encode(combo) else { return }
        defaults.set(data, forKey: key)
    }
}
