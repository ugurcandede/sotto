import Foundation

/// Anonymous usage analytics over the GA4 Measurement Protocol.
///
/// Events carry a random install id, the app version and what was used —
/// never audio, keys or device names. Everything is off when "send anonymous
/// usage stats" is unchecked. The Measurement Protocol does not derive
/// geography from the IP.
///
/// Events are queued in UserDefaults and sent one request each, stamped with
/// the time they happened, so nothing is lost offline. GA accepts timestamps up
/// to 72 hours old; older queued events are dropped.
///
/// Same file as taplock-app's, app-agnostic apart from the constants below and
/// storage going through `Settings.defaults` (which tests swap out).
enum Analytics {
    /// GA4 → Admin → Data streams → Measurement Protocol API secrets.
    /// The property is shared across apps; app_name is the discriminator.
    private static let measurementID = "G-DCYDCWCN8V"
    private static let apiSecret = "RzYiYu4ISFCAwL6K4ZuiUA"
    private static let appName = "sotto"

    private static let maxEventAge: TimeInterval = 72 * 3600
    private static let maxQueueLength = 500
    /// Realtime shows the last 30 minutes, so an active user reports in just inside that.
    private static let heartbeatInterval: TimeInterval = 25 * 60
    /// Short enough that Realtime feels live, long enough to send a burst together.
    private static let flushDelay: TimeInterval = 5
    private static let dailyCheckInterval: TimeInterval = 6 * 3600

    /// Session = one app launch.
    private static let launchDate = Date()
    private static let sessionID = String(Int(launchDate.timeIntervalSince1970))
    private static var started = false
    private static var isFlushing = false
    private static var flushScheduled = false
    private static var lastHeartbeat = launchDate
    private static var appUserProperties: [String: Any] = [:]

    // MARK: - API

    /// Call once at launch. `heartbeat` returns params when there was activity
    /// worth reporting since the last call, nil otherwise.
    static func start(heartbeat: @escaping () -> [String: Any]?) {
        guard !started else { return }
        started = true

        let isFirstLaunch = Settings.defaults.string(forKey: "analyticsClientID") == nil
        _ = Settings.analyticsClientID
        if firstLaunchDate == nil { firstLaunchDate = launchDate }

        let previousVersion = Settings.defaults.string(forKey: "analyticsLastVersion")
        Settings.defaults.set(appVersion, forKey: "analyticsLastVersion")
        if isFirstLaunch {
            track("app_first_launch")
        } else if let previousVersion, previousVersion != appVersion {
            track("app_update", ["from_version": previousVersion])
        }
        track("app_launch")

        pingIfDue()
        Timer.scheduledTimer(withTimeInterval: dailyCheckInterval, repeats: true) { _ in pingIfDue() }
        Timer.scheduledTimer(withTimeInterval: heartbeatInterval, repeats: true) { _ in
            guard let params = heartbeat() else { return }
            let elapsed = Date().timeIntervalSince(lastHeartbeat)
            lastHeartbeat = Date()
            track("heartbeat", params, engagementMs: Int(elapsed * 1000))
        }
        flush()
    }

    /// Queue an event. Parameter values should be String, Int, Double or Bool;
    /// GA truncates strings past 100 characters. No-op before `start()`, which
    /// keeps tests off the network.
    static func track(_ name: String, _ params: [String: Any] = [:], engagementMs: Int = 100) {
        guard started, Settings.analyticsEnabled else { return }
        enqueue(name, params, at: Date(), engagementMs: engagementMs)
        scheduleFlush()
    }

    /// App-specific user properties, merged into the built-in ones on every request.
    static func setUserProperties(_ properties: [String: Any]) {
        appUserProperties.merge(stringifyingBools(properties)) { _, new in new }
    }

    /// Usage stats were switched off: drop anything still waiting.
    static func disabled() {
        queue = []
    }

    /// Record the quit and try to send it. The request may not finish before the
    /// process exits; the event stays queued and goes out on next launch.
    static func appWillTerminate() {
        track("app_quit", ["uptime_sec": Int(Date().timeIntervalSince(launchDate))])
        flush()
    }

    // MARK: - Daily ping

    /// One `daily_ping` per day keeps daily actives honest for an app that can
    /// run for weeks between launches. Days missed offline are backfilled for
    /// the two previous days — older ones are past GA's 72 h limit.
    private static func pingIfDue() {
        guard Settings.analyticsEnabled else { return }
        let now = Date()
        guard Settings.lastAnalyticsPing != day(now) else { return }
        for date in unsentDates(now: now) {
            enqueue("daily_ping", [
                "ping_type": date == now ? "live" : "backfill",
                "mode": Settings.mode.rawValue,
            ], at: date)
        }
        // The queue is persistent, so the day counts as sent once it is queued.
        Settings.lastAnalyticsPing = day(now)
        scheduleFlush()
    }

    static func unsentDates(now: Date) -> [Date] {
        guard let lastSent = Settings.lastAnalyticsPing else { return [now] }
        var dates: [Date] = []
        for offset in [2, 1] {
            guard let past = Calendar.current.date(byAdding: .day, value: -offset, to: now) else { continue }
            if day(past) > lastSent { dates.append(past) }
        }
        dates.append(now)
        return dates
    }

    // MARK: - Queue and sending

    /// GA documents parameter values as strings or numbers; booleans are sent as
    /// "true" / "false" so they report as readable dimension values.
    private static func stringifyingBools(_ values: [String: Any]) -> [String: Any] {
        values.mapValues { value in (value as? Bool).map { $0 ? "true" : "false" } ?? value }
    }

    private static func enqueue(_ name: String, _ params: [String: Any], at date: Date, engagementMs: Int = 100) {
        var event = stringifyingBools(params)
        event["app_name"] = appName
        event["app_version"] = appVersion
        event["session_id"] = sessionID
        // Required for the event to count toward active users.
        event["engagement_time_msec"] = max(1, engagementMs)
        var queued = queue
        queued.append([
            "id": UUID().uuidString,
            "name": name,
            "params": event,
            "ts": Int(date.timeIntervalSince1970 * 1_000_000),
        ])
        queue = Array(queued.suffix(maxQueueLength))
    }

    private static func scheduleFlush() {
        guard !flushScheduled else { return }
        flushScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + flushDelay) {
            flushScheduled = false
            flush()
        }
    }

    /// Send queued events oldest first, one request each. Stops at the first
    /// network failure; the rest wait for the next flush.
    static func flush() {
        guard Settings.analyticsEnabled, !isFlushing else { return }
        let cutoff = Int((Date().timeIntervalSince1970 - maxEventAge) * 1_000_000)
        queue = queue.filter { ($0["ts"] as? Int ?? 0) > cutoff }
        guard let event = queue.first else { return }

        isFlushing = true
        send(event) { ok in
            isFlushing = false
            guard ok else { return }
            queue = queue.filter { $0["id"] as? String != event["id"] as? String }
            flush()
        }
    }

    private static func send(_ event: [String: Any], completion: @escaping (Bool) -> Void) {
        var request = URLRequest(url: URL(string:
            "https://www.google-analytics.com/mp/collect?measurement_id=\(measurementID)&api_secret=\(apiSecret)")!)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody(for: event))

        URLSession.shared.dataTask(with: request) { _, response, _ in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            DispatchQueue.main.async { completion((200..<300).contains(status)) }
        }.resume()
    }

    static func requestBody(for event: [String: Any]) -> [String: Any] {
        [
            "client_id": Settings.analyticsClientID,
            "timestamp_micros": event["ts"] ?? 0,
            "user_properties": userProperties().mapValues { ["value": $0] },
            "events": [["name": event["name"] ?? "", "params": event["params"] ?? [:]]],
        ]
    }

    static func userProperties() -> [String: Any] {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        var properties: [String: Any] = [
            "app_name": appName,
            "app_version": appVersion,
            "platform": "macos",
            "os_version": "\(os.majorVersion).\(os.minorVersion)",
            "arch": arch,
            "language": Locale.current.language.languageCode?.identifier ?? "unknown",
        ]
        if let first = firstLaunchDate {
            // ISO week of the first launch, e.g. 2026-W39 — for retention cohorts.
            let calendar = Calendar(identifier: .iso8601)
            let week = calendar.component(.weekOfYear, from: first)
            let year = calendar.component(.yearForWeekOfYear, from: first)
            properties["install_week"] = String(format: "%d-W%02d", year, week)
        }
        return properties.merging(appUserProperties) { _, app in app }
    }

    // MARK: - Storage

    static var queue: [[String: Any]] {
        get { Settings.defaults.array(forKey: "analyticsQueue") as? [[String: Any]] ?? [] }
        set { Settings.defaults.set(newValue, forKey: "analyticsQueue") }
    }

    private static var firstLaunchDate: Date? {
        get { Settings.defaults.object(forKey: "analyticsFirstLaunch") as? Date }
        set { Settings.defaults.set(newValue, forKey: "analyticsFirstLaunch") }
    }

    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }

    private static var arch: String {
        #if arch(arm64)
        return "arm64"
        #else
        return "x86_64"
        #endif
    }

    private static func day(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
