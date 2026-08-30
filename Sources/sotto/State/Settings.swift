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

    static var mode: TriggerMode {
        get {
            let stored = TriggerMode(rawValue: defaults.string(forKey: "mode") ?? "") ?? .toggle
            return TriggerMode.selectable.contains(stored) ? stored : .toggle
        }
        set { defaults.set(newValue.rawValue, forKey: "mode") }
    }

    static var showHUD: Bool {
        get { defaults.object(forKey: "showHUD") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showHUD") }
    }

    /// Set once the tap has actually armed. If the grant later reads as
    /// missing, it is a stale record from an earlier binary (updates change
    /// the ad-hoc signature), not a fresh install — the notice can say so.
    static var hadAccessibility: Bool {
        get { defaults.bool(forKey: "hadAccessibility") }
        set { defaults.set(newValue, forKey: "hadAccessibility") }
    }

    static var analyticsEnabled: Bool {
        get { defaults.object(forKey: "analyticsEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "analyticsEnabled") }
    }

    /// yyyy-MM-dd of the last ping, so a day gets at most one.
    static var lastAnalyticsPing: String? {
        get { defaults.string(forKey: "lastAnalyticsPing") }
        set { defaults.set(newValue, forKey: "lastAnalyticsPing") }
    }

    /// Random id minted on first use — the only identifier analytics sends.
    static var analyticsClientID: String {
        if let id = defaults.string(forKey: "analyticsClientID") { return id }
        let id = UUID().uuidString
        defaults.set(id, forKey: "analyticsClientID")
        return id
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
