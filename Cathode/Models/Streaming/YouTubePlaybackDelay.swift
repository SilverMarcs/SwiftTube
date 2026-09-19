import Foundation

/// Mirrors yt-dlp's pre-playback availability wait. Newly issued media URLs
/// can return 403 until this deadline; re-extracting restarts the wait.
nonisolated enum YouTubePlaybackDelay {
    static func seconds(in data: Data) -> Double {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return 0 }
        var renderers: [[String: Any]] = []
        for placement in root["adPlacements"] as? [[String: Any]] ?? [] {
            guard let renderer = placement["adPlacementRenderer"] as? [String: Any],
                  let config = renderer["config"] as? [String: Any],
                  let adConfig = config["adPlacementConfig"] as? [String: Any],
                  adConfig["kind"] as? String == "AD_PLACEMENT_KIND_START",
                  let content = renderer["renderer"] as? [String: Any] else { continue }
            collect(content, into: &renderers)
        }
        for slot in root["adSlots"] as? [[String: Any]] ?? [] {
            guard let renderer = slot["adSlotRenderer"] as? [String: Any],
                  let metadata = renderer["adSlotMetadata"] as? [String: Any],
                  metadata["triggerEvent"] as? String == "SLOT_TRIGGER_EVENT_BEFORE_CONTENT",
                  let fulfillment = renderer["fulfillmentContent"] as? [String: Any] else { continue }
            collect(fulfillment, into: &renderers)
        }
        return renderers.reduce(0) { total, ad in
            if let skip = ad["skipOffsetMilliseconds"] as? Double, skip >= 0 { return total + skip / 1000 }
            guard let parameters = ad["playerVars"] as? String,
                  let query = URLComponents(string: "https://localhost/?" + parameters)?.queryItems,
                  let raw = query.first(where: { $0.name == "length_seconds" })?.value,
                  let seconds = Double(raw), seconds >= 0 else { return total }
            return total + seconds
        }
    }

    private static func collect(_ node: [String: Any], into results: inout [[String: Any]]) {
        if let ad = node["instreamVideoAdRenderer"] as? [String: Any] { results.append(ad); return }
        for value in node.values {
            if let child = value as? [String: Any] { collect(child, into: &results) }
            if let children = value as? [[String: Any]] {
                for child in children { collect(child, into: &results) }
            }
        }
    }
}
