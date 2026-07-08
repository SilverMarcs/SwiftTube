import Foundation

// MARK: - Shorts feed
//
// The personalised "For You" Shorts feed, matching how YouTube's own Shorts tab
// works: an initial personalised set, then an endless `reel_watch_sequence` paged
// by a continuation token.
//
// FEshorts (the old dedicated Shorts browse) returns HTTP 400 on every client and
// is not used. Instead:
//   1. `fetchShorts()` pulls the Shorts shelf out of the personalised home feed
//      (`FEwhat_to_watch`, cookie account) — rich, one request, the first screen.
//   2. `fetchShortsMore(_:)` runs `reel_watch_sequence`, seeded once from the first
//      home Short, then paged forever via its continuation token.
//
// Personalisation rides on the account's cookies (SAPISIDHASH). The sequence falls
// back to an unauthenticated request if cookies are unavailable — the seed already
// carries the personalisation, so the fallback stays relevant.

extension InnerTubeAPI {

    /// Marks a `nextPageToken` that carries a reel seed videoId (first sequence page)
    /// rather than a raw continuation token.
    private static let reelSeedPrefix = "reelseed:"

    /// First screen of the Shorts feed: the Shorts already in the personalised home
    /// feed. `nextPageToken` carries a seed marker that `fetchShortsMore` expands.
    public func fetchShorts() async throws -> VideoGroup {
        let data = try await personalisedHomeFeed()
        // WEB home stores Shorts in shortsLockup/reel structures the rich parser may
        // not flag as `isShort`, so also run a reelWatchEndpoint scan (proven by the
        // diagnostics to find all of them) and keep whichever set is more complete.
        let rich = (try? parseVideoGroup(from: data, title: "Shorts").videos.filter(\.isShort)) ?? []
        let scanned = Self.reelShortVideos(from: data)
        let shorts = scanned.count > rich.count ? scanned : rich
        if let seed = shorts.first?.id {
            return VideoGroup(
                title: "Shorts",
                videos: shorts,
                nextPageToken: Self.reelSeedPrefix + seed)
        }
        // 2026-07: the authenticated home feed stopped carrying a Shorts shelf
        // entirely. The reel sequence still works and personalises via the
        // account cookies, so seed it from a random first-shelf video.
        guard let seed = parseVideoGroupRows(from: data).first?.videos.randomElement()?.id else {
            return VideoGroup(title: "Shorts", videos: [], nextPageToken: nil)
        }
        return try await fetchShortsMore(continuationToken: Self.reelSeedPrefix + seed)
    }

    /// Next page of the Shorts feed via `reel_watch_sequence`. The token is either a
    /// seed marker (first page) or a raw continuation token (subsequent pages).
    public func fetchShortsMore(continuationToken token: String) async throws -> VideoGroup {
        let params = token.hasPrefix(Self.reelSeedPrefix)
            ? Self.encodeReelSeed(videoId: String(token.dropFirst(Self.reelSeedPrefix.count)))
            : token
        let (videos, continuation) = await reelSequence(sequenceParams: params)
        return VideoGroup(title: "Shorts", videos: videos, nextPageToken: continuation)
    }

    // MARK: - Personalised home

    /// Fetches the personalised home feed (`FEwhat_to_watch`), which carries the
    /// Shorts shelf. Cookie account first (the youtube.com For You feed), then TV
    /// OAuth, then signed-out. Warms the cookie store first so the first call after
    /// launch doesn't miss the SAPISIDHASH.
    private func personalisedHomeFeed() async throws -> [String: Any] {
        await YTCookieAuth.shared.refreshSignInState()
        var body = makeBody(client: webClientContext, includeVisitorData: true)
        body["browseId"] = "FEwhat_to_watch"

        if await YTCookieAuth.shared.sapisidHashAuthorization() != nil,
           let data = try? await postWebAuthenticated(endpoint: "browse", body: body) {
            return data
        }
        if authToken != nil {
            var tv = makeBody(client: tvClientContext, includeVisitorData: true)
            tv["browseId"] = "FEwhat_to_watch"
            return try await postTV(endpoint: "browse", body: tv)
        }
        return try await post(endpoint: "browse", body: body)
    }

    // MARK: - reel_watch_sequence

    /// One page of the reel sequence. Cookie account first (personalised), then an
    /// unauthenticated request as a fallback.
    private func reelSequence(sequenceParams: String) async -> (videos: [Video], continuation: String?) {
        var body = makeBody(client: webClientContext, includeVisitorData: true)
        body["sequenceParams"] = sequenceParams

        if await YTCookieAuth.shared.sapisidHashAuthorization() != nil,
           let data = try? await postWebAuthenticated(endpoint: "reel/reel_watch_sequence", body: body) {
            let parsed = Self.parseReelSequence(data)
            if !parsed.videos.isEmpty { return parsed }
        }
        if let data = try? await post(endpoint: "reel/reel_watch_sequence", body: body) {
            return Self.parseReelSequence(data)
        }
        return ([], nil)
    }

    /// Scans a browse response for every `reelWatchEndpoint.videoId` (the definitive
    /// Shorts marker) and builds minimal Short videos. Used for the home Shorts shelf
    /// when the rich parser doesn't flag them; metadata resolves on playback.
    private static func reelShortVideos(from data: [String: Any]) -> [Video] {
        var videos: [Video] = []
        var seen = Set<String>()
        func walk(_ any: Any) {
            if let dict = any as? [String: Any] {
                if let reel = dict["reelWatchEndpoint"] as? [String: Any],
                   let videoId = reel["videoId"] as? String,
                   seen.insert(videoId).inserted {
                    videos.append(Video(id: videoId, title: "", channelTitle: "",
                                        isShort: true, hasPortraitThumbnail: true))
                }
                for value in dict.values { walk(value) }
            } else if let arr = any as? [Any] {
                for value in arr { walk(value) }
            }
        }
        walk(data)
        return videos
    }

    /// Parses a `reel_watch_sequence` response into Shorts + the raw continuation
    /// token. Only the prefetched (first) entry carries full metadata; the rest are
    /// videoId + portrait thumbnail, which the player resolves on playback.
    private static func parseReelSequence(_ data: [String: Any]) -> (videos: [Video], continuation: String?) {
        var videos: [Video] = []
        var seen = Set<String>()
        for entry in data["entries"] as? [[String: Any]] ?? [] {
            guard let command = entry["command"] as? [String: Any],
                  let reel = command["reelWatchEndpoint"] as? [String: Any],
                  let videoId = reel["videoId"] as? String,
                  seen.insert(videoId).inserted else { continue }
            let details = ((reel["unserializedPrefetchData"] as? [String: Any])?["playerResponse"]
                as? [String: Any])?["videoDetails"] as? [String: Any]
            videos.append(Video(
                id: videoId,
                title: details?["title"] as? String ?? "",
                channelTitle: details?["author"] as? String ?? "",
                channelId: details?["channelId"] as? String,
                duration: (details?["lengthSeconds"] as? String).flatMap(TimeInterval.init),
                isShort: true,
                hasPortraitThumbnail: true))
        }
        let continuation = ((data["continuationEndpoint"] as? [String: Any])?["continuationCommand"]
            as? [String: Any])?["token"] as? String
        return (videos, continuation)
    }

    // MARK: - Seed protobuf

    /// Encodes the `ReelSequence` protobuf that seeds the sequence, url-encoded as
    /// `sequenceParams`. Fields: `short_id`=1, `params.number`=3 (=5), `feature_2`=10 (=25).
    private static func encodeReelSeed(videoId: String) -> String {
        var out: [UInt8] = []
        appendString(&out, field: 1, value: videoId)
        var params: [UInt8] = []
        appendVarint(&params, field: 3, value: 5)
        appendMessage(&out, field: 5, value: params)
        appendVarint(&out, field: 10, value: 25)
        let base64 = Data(out).base64EncodedString()
        return base64.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? base64
    }

    private static func appendTag(_ out: inout [UInt8], field: Int, wire: Int) {
        var v = UInt64((field << 3) | wire)
        repeat { var b = UInt8(v & 0x7F); v >>= 7; if v != 0 { b |= 0x80 }; out.append(b) } while v != 0
    }

    private static func appendVarint(_ out: inout [UInt8], field: Int, value: UInt64) {
        appendTag(&out, field: field, wire: 0)
        var v = value
        repeat { var b = UInt8(v & 0x7F); v >>= 7; if v != 0 { b |= 0x80 }; out.append(b) } while v != 0
    }

    private static func appendString(_ out: inout [UInt8], field: Int, value: String) {
        appendMessage(&out, field: field, value: Array(value.utf8))
    }

    private static func appendMessage(_ out: inout [UInt8], field: Int, value: [UInt8]) {
        appendTag(&out, field: field, wire: 2)
        var len = UInt64(value.count)
        repeat { var b = UInt8(len & 0x7F); len >>= 7; if len != 0 { b |= 0x80 }; out.append(b) } while len != 0
        out += value
    }
}
