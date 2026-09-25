import Foundation

struct AppUpdate: Equatable {
    let version: String
    let url: URL
}

/// Checks GitHub for a release newer than the running build.
///
/// Unauthenticated GitHub API calls are limited to 60 an hour per IP; the app
/// checks at launch and once a day, far below that. A dismissed version stays
/// hidden until a newer one is published.
///
/// Same file as taplock-app's, app-agnostic apart from the two constants below.
enum UpdateChecker {
    private static let repo = "ugurcandede/sotto"
    static let brewCommand = "brew upgrade --cask sotto"

    static func check(completion: @escaping (AppUpdate?) -> Void) {
        let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request) { data, _, _ in
            let update = data.flatMap { parseRelease($0, currentVersion: Analytics.appVersion) }
            DispatchQueue.main.async { completion(update) }
        }.resume()
    }

    static var dismissedVersion: String? {
        get { Settings.defaults.string(forKey: "updateDismissedVersion") }
        set { Settings.defaults.set(newValue, forKey: "updateDismissedVersion") }
    }

    /// The release in `data` if it is newer than `currentVersion` and not dismissed.
    static func parseRelease(_ data: Data, currentVersion: String) -> AppUpdate? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let page = (json["html_url"] as? String).flatMap(URL.init(string:))
        else { return nil }
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        guard isNewer(version, than: currentVersion), version != dismissedVersion else { return nil }
        return AppUpdate(version: version, url: page)
    }

    /// Numeric dot-separated comparison: 1.10.0 is newer than 1.9.3.
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let b = current.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
