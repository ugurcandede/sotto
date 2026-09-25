import Foundation
import Testing

@testable import sotto

/// Analytics and the update check read `Settings.defaults`, which tests swap for
/// a throwaway suite. Nested in `SettingsTests` so its `.serialized` covers these
/// too — two suites swapping the same global in parallel corrupt each other.
extension SettingsTests {
    @Suite("Analytics and updates")
    struct AnalyticsTests {

        private func withScratchDefaults(_ body: () throws -> Void) rethrows {
            let name = "sotto.tests.\(UUID().uuidString)"
            let original = Settings.defaults
            Settings.defaults = UserDefaults(suiteName: name)!
            defer {
                Settings.defaults = original
                UserDefaults.standard.removePersistentDomain(forName: name)
            }
            try body()
        }

        @Test func trackBeforeStartIsNoop() {
            withScratchDefaults {
                Analytics.track("should_not_queue")
                #expect(Analytics.queue.isEmpty)
            }
        }

        @Test func requestBodyShape() {
            withScratchDefaults {
                let event: [String: Any] = ["id": "x", "name": "mute_toggled", "params": ["source": "hotkey"], "ts": 123]
                let body = Analytics.requestBody(for: event)
                #expect(body["timestamp_micros"] as? Int == 123)
                #expect(body["client_id"] as? String == Settings.analyticsClientID)
                let events = body["events"] as? [[String: Any]]
                #expect(events?.first?["name"] as? String == "mute_toggled")
                let props = body["user_properties"] as? [String: [String: Any]]
                #expect(props?["app_name"]?["value"] as? String == "sotto")
                #expect(props?["platform"]?["value"] as? String == "macos")
            }
        }

        @Test func boolUserPropertiesBecomeStrings() {
            Analytics.setUserProperties(["test_flag": true, "test_count": 3])
            let props = Analytics.userProperties()
            #expect(props["test_flag"] as? String == "true")
            #expect(props["test_count"] as? Int == 3)
        }

        @Test func versionComparison() {
            #expect(UpdateChecker.isNewer("0.5.0", than: "0.4.2"))
            #expect(UpdateChecker.isNewer("0.10.0", than: "0.9.9"))
            #expect(!UpdateChecker.isNewer("0.4.2", than: "0.4.2"))
            #expect(!UpdateChecker.isNewer("0.4", than: "0.4.0"))
        }

        @Test func parsesOnlyNewerUndismissedReleases() {
            withScratchDefaults {
                let json = Data(#"{"tag_name":"v9.0.0","html_url":"https://github.com/ugurcandede/sotto/releases/tag/v9.0.0"}"#.utf8)
                #expect(UpdateChecker.parseRelease(json, currentVersion: "0.4.2")?.version == "9.0.0")
                #expect(UpdateChecker.parseRelease(json, currentVersion: "9.0.0") == nil)
                UpdateChecker.dismissedVersion = "9.0.0"
                #expect(UpdateChecker.parseRelease(json, currentVersion: "0.4.2") == nil)
                #expect(UpdateChecker.parseRelease(Data(#"{"message":"rate limited"}"#.utf8), currentVersion: "0.4.2") == nil)
            }
        }
    }
}
