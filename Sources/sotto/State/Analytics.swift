import Foundation

/// One anonymous ping per day to Google Analytics (Measurement Protocol):
/// a random install id and the current trigger mode, nothing else. Off when
/// "send anonymous usage stats" is unchecked. The Measurement Protocol does
/// not derive geography from the IP, and no other identifier leaves the Mac.
enum Analytics {
    /// GA4 → Admin → Data Streams → choose stream → Measurement Protocol
    /// API secrets. Empty means analytics is compiled out entirely.
    private static let measurementID = "G-DCYDCWCN8V"
    private static let apiSecret = "RzYiYu4ISFCAwL6K4ZuiUA"
    /// The property is shared across apps; this is the per-app discriminator.
    private static let appName = "sotto"

    static func start() {
        pingIfDue()
        // The app can run for weeks between launches; a timer keeps daily
        // actives honest. pingIfDue itself sends at most once per day.
        Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { _ in
            pingIfDue()
        }
    }

    private static func pingIfDue() {
        guard !measurementID.isEmpty, !apiSecret.isEmpty, Settings.analyticsEnabled else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        guard Settings.lastAnalyticsPing != today else { return }
        Settings.lastAnalyticsPing = today

        var request = URLRequest(url: URL(string:
            "https://www.google-analytics.com/mp/collect?measurement_id=\(measurementID)&api_secret=\(apiSecret)")!)
        request.httpMethod = "POST"

        // session_id and engagement_time_msec are required for the ping to
        // count as an active user in GA4 reports, not just an event.
        let body: [String: Any] = [
            "client_id": Settings.analyticsClientID,
            "events": [[
                "name": "daily_ping",
                "params": [
                    "app_name": appName,
                    "mode": Settings.mode.rawValue,
                    "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev",
                    "session_id": String(Int(Date().timeIntervalSince1970)),
                    "engagement_time_msec": 100
                ]
            ]]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: request).resume()
    }
}
