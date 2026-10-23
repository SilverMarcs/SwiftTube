import Foundation

// MARK: - Shorts feed
//
// The TV app's Shorts tab: a seedless `reel_item_watch` opens the account's
// personalised sequence, then `reel_watch_sequence` pages it by continuation.
// Sequence entries carry only a videoId; metadata resolves on playback.

extension InnerTubeAPI {

    /// Opens the seedless sequence. Its first Short comes back as the
    /// replacement endpoint, followed by the first sequence page.
    public func fetchShorts() async throws -> VideoGroup {
        var body = makeBody(client: tvClientContext)
        body["params"] = "CA8="
        body["inputType"] = "REEL_WATCH_INPUT_TYPE_SEEDLESS"
        body["disablePlayerResponse"] = true
        let token = try await YTTVAuthManager.shared.validAccessToken()
        let data = try await postTV(endpoint: "reel/reel_item_watch", body: body, explicitBearerToken: token)

        let first = ((data["replacementEndpoint"] as? [String: Any])?["reelWatchEndpoint"] as? [String: Any])
            .flatMap(Self.short(from:))
        guard let sequence = data["sequenceContinuation"] as? String else {
            return VideoGroup(title: "Shorts", videos: first.map { [$0] } ?? [], nextPageToken: nil)
        }
        let page = try await fetchShortsMore(continuationToken: sequence)
        return VideoGroup(title: "Shorts",
                          videos: (first.map { [$0] } ?? []) + page.videos,
                          nextPageToken: page.nextPageToken)
    }

    /// One page of the sequence. Ad entries are skipped.
    public func fetchShortsMore(continuationToken: String) async throws -> VideoGroup {
        var body = makeBody(client: tvClientContext)
        body["sequenceParams"] = continuationToken
        let token = try await YTTVAuthManager.shared.validAccessToken()
        let data = try await postTV(endpoint: "reel/reel_watch_sequence", body: body, explicitBearerToken: token)

        let videos = (data["entries"] as? [[String: Any]] ?? []).compactMap { entry -> Video? in
            guard let reel = (entry["command"] as? [String: Any])?["reelWatchEndpoint"] as? [String: Any],
                  reel["adClientParams"] == nil else { return nil }
            return Self.short(from: reel)
        }
        return VideoGroup(title: "Shorts", videos: videos, nextPageToken: data["continuation"] as? String)
    }

    private static func short(from reel: [String: Any]) -> Video? {
        guard let videoId = reel["videoId"] as? String else { return nil }
        return Video(id: videoId, title: "", channelTitle: "", isShort: true, hasPortraitThumbnail: true)
    }
}
