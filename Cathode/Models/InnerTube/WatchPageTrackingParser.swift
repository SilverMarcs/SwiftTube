import Foundation

nonisolated enum WatchPageTrackingParser {
    enum Failure: Error {
        case missingPlayerResponse
        case unauthenticated
        case wrongVideo
        case missingTrackingURLs
    }

    static func parse(_ html: String, videoID: String) throws -> PlaybackTrackingURLs {
        // Match an assignment, not an arbitrary occurrence of the variable in
        // another script. Scan balanced JSON so braces inside strings are safe.
        let pattern = #"(?:var\s+ytInitialPlayerResponse|window\s*\[\s*["']ytInitialPlayerResponse["']\s*\]|ytInitialPlayerResponse)\s*=\s*\{"#
        let expression = try NSRegularExpression(pattern: pattern)
        for match in expression.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
            guard let range = Range(match.range, in: html),
                  let data = jsonObject(in: html[html.index(before: range.upperBound)...]),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }
            return try trackingURLs(in: json, videoID: videoID)
        }
        throw Failure.missingPlayerResponse
    }

    private static func trackingURLs(in json: [String: Any], videoID: String) throws -> PlaybackTrackingURLs {
        let context = json["responseContext"] as? [String: Any]
        let webContext = context?["mainAppWebResponseContext"] as? [String: Any]
        // Anonymous player responses also contain valid-looking tracking URLs.
        // Require affirmative authentication instead of assuming their presence
        // means that YouTube will save the view to the user's account.
        guard webContext?["loggedOut"] as? Bool == false else {
            throw Failure.unauthenticated
        }
        let details = json["videoDetails"] as? [String: Any]
        guard details?["videoId"] as? String == videoID else { throw Failure.wrongVideo }
        let tracking = json["playbackTracking"] as? [String: Any]
        guard let playbackURL = trackingURL(tracking?["videostatsPlaybackUrl"], path: "/api/stats/playback"),
              let watchtimeURL = trackingURL(tracking?["videostatsWatchtimeUrl"], path: "/api/stats/watchtime") else {
            throw Failure.missingTrackingURLs
        }
        let config = json["playerConfig"] as? [String: Any]
        let vss = config?["vssClientConfig"] as? [String: Any]
        return PlaybackTrackingURLs(
            playbackURL: playbackURL,
            watchtimeURL: watchtimeURL,
            usesPOST: vss?["vssUsePostRequest"] as? Bool ?? false
        )
    }

    private static func trackingURL(_ value: Any?, path: String) -> URL? {
        guard let value = value as? [String: Any], let raw = value["baseUrl"] as? String,
              let url = URL(string: raw), url.scheme == "https",
              let host = url.host(), host == "youtube.com" || host.hasSuffix(".youtube.com"),
              url.path() == path else { return nil }
        return url
    }

    private static func jsonObject(in text: Substring) -> Data? {
        var depth = 0
        var inString = false
        var escaped = false
        for index in text.indices {
            let character = text[index]
            if inString {
                if escaped { escaped = false }
                else if character == "\\" { escaped = true }
                else if character == "\"" { inString = false }
            } else {
                switch character {
                case "\"": inString = true
                case "{": depth += 1
                case "}":
                    depth -= 1
                    if depth == 0 { return Data(text[...index].utf8) }
                default: break
                }
            }
        }
        return nil
    }
}
