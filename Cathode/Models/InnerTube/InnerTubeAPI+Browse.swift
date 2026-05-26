import Foundation
import os
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private let tubeLog = Logger(subsystem: appSubsystem, category: "InnerTube")

// MARK: - Browse endpoints

extension InnerTubeAPI {

    // MARK: - Visitor data helper

    /// Extracts `responseContext.visitorData` from a browse response and stores it.
    /// The stored token is included in subsequent home-feed requests so YouTube can
    /// tailor recommendations to this specific device/session.
    func updateVisitorData(from response: [String: Any]) {
        guard let ctx = response["responseContext"] as? [String: Any],
              let vd = ctx["visitorData"] as? String, !vd.isEmpty else { return }
        visitorData = vd
    }

    // MARK: - Home

    /// Fetches the home feed.
    /// When authenticated, uses TVHTML5 on youtubei.googleapis.com for a personalised feed.
    /// When unauthenticated, uses the WEB client on www.youtube.com for the default feed.
    public func fetchHome(continuationToken: String? = nil) async throws -> VideoGroup {
        let isAuth = authToken != nil
        var body = makeBody(client: isAuth ? tvClientContext : webClientContext,
                            continuationToken: continuationToken,
                            includeVisitorData: true)
        if continuationToken == nil {
            body["browseId"] = "FEwhat_to_watch"
        }
        let data = isAuth
            ? try await postTV(endpoint: "browse", body: body)
            : try await post(endpoint: "browse", body: body)
        updateVisitorData(from: data)
        return try parseVideoGroup(from: data, title: BrowseSection.SectionType.home.defaultTitle)
    }

    /// Fetches the home feed as multiple named shelves (TYPE_ROW in Android).
    /// Returns one VideoGroup per shelf; each has layout == .row.
    /// Falls back to a single flat VideoGroup if no shelves are found.
    public func fetchHomeRows(continuationToken: String? = nil) async throws -> [VideoGroup] {
        let isAuth = authToken != nil
        var body = makeBody(client: isAuth ? tvClientContext : webClientContext,
                            continuationToken: continuationToken,
                            includeVisitorData: true)
        if continuationToken == nil {
            body["browseId"] = "FEwhat_to_watch"
        }
        let data = isAuth
            ? try await postTV(endpoint: "browse", body: body)
            : try await post(endpoint: "browse", body: body)
        updateVisitorData(from: data)
        let rows = parseVideoGroupRows(from: data)
        tubeLog.notice("fetchHomeRows → \(rows.count, privacy: .public) shelves")
        let rowShortsDetail = rows.map { row -> String in
            let s = row.videos.filter { $0.isShort }.count
            return "'\(row.title ?? "?")': \(s)/\(row.videos.count) shorts"
        }.joined(separator: ", ")
        tubeLog.notice("fetchHomeRows shelf detail: [\(rowShortsDetail, privacy: .public)]")
        return rows
    }

    public func fetchAllRecommendations(maxPages: Int = 5) async throws -> [Video] {
        guard authToken != nil else { return [] }
        var all: [Video] = []
        var token: String? = nil
        for _ in 0..<maxPages {
            let group = try await fetchHome(continuationToken: token)
            all.append(contentsOf: group.videos)
            guard let next = group.nextPageToken, !next.isEmpty else { break }
            token = next
        }
        return all
    }

    // MARK: - Subscriptions

    /// Fetches subscriptions feed (requires auth).
    /// Uses TVHTML5 client on youtubei.googleapis.com — the only endpoint that accepts
    /// the OAuth token issued by the TV device-code flow.
    public func fetchSubscriptions(continuationToken: String? = nil) async throws -> VideoGroup {
        var body = makeBody(client: tvClientContext, continuationToken: continuationToken)
        if continuationToken == nil {
            body["browseId"] = "FEsubscriptions"
        }
        let data = try await postTV(endpoint: "browse", body: body)
        var group = try parseVideoGroup(from: data, title: "Subscriptions")
        // Sort newest-first so the feed is in chronological order regardless of the
        // order YouTube's API returns tiles. Matches LocalSubscriptionFeedService behaviour.
        group.videos.sort { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
        return group
    }

    /// Fetches the list of channels the authenticated user subscribes to (requires auth).
    ///
    /// Calls TV `/browse?FEchannels` — the "Subscriptions → Channels" tab. Returns
    /// every subscribed channel as a `TILE_CONTENT_TYPE_CHANNEL` tile with avatar,
    /// @handle, and subscriber count.
    public func fetchSubscribedChannels() async throws -> [Channel] {
        var body = makeBody(client: tvClientContext)
        body["browseId"] = "FEchannels"
        let data = try await postTV(endpoint: "browse", body: body)
        let channels = parseChannelsTab(from: data)
        tubeLog.notice("fetchSubscribedChannels FEchannels → \(channels.count, privacy: .public) channels")
        return channels
    }

    // MARK: - History

    /// Fetches the user's watch history (requires TV OAuth). Browse-style
    /// `FEhistory` works with the TV client even though the same client's
    /// /player endpoint is IP-blocked — the restriction is player-only.
    public func fetchHistory(continuationToken: String? = nil) async throws -> VideoGroup {
        var body = makeBody(client: tvClientContext, continuationToken: continuationToken)
        if continuationToken == nil {
            body["browseId"] = "FEhistory"
        }
        let data = try await postTV(endpoint: "browse", body: body)
        return try parseVideoGroup(from: data, title: "History")
    }

    // MARK: - Search

    public func search(
        query: String,
        continuationToken: String? = nil,
        filter: SearchFilter = .default
    ) async throws -> VideoGroup {
        var body = makeBody(client: webClientContext, continuationToken: continuationToken)
        if continuationToken == nil {
            body["query"] = query
            if let params = filter.encodedParams() {
                body["params"] = params
            }
        }
        let data = try await post(endpoint: "search", body: body)
        return try parseVideoGroup(from: data, title: "Search: \(query)")
    }

    public func fetchSearchSuggestions(query: String) async throws -> [String] {
        guard var components = URLComponents(string: "https://suggestqueries-clients6.youtube.com/complete/search") else {
            return []
        }
        components.queryItems = [
            URLQueryItem(name: "client", value: "youtube"),
            URLQueryItem(name: "ds", value: "yt"),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "callback", value: ""),
        ]
        guard let url = components.url else { return [] }
        print("[Suggestions] Fetching URL: \(url)")
        let (data, response) = try await session.data(from: url)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        print("[Suggestions] HTTP status: \(statusCode), bytes: \(data.count)")
        // Response format: [query, [[suggestion, 0, []], ...], ...]
        guard let raw = String(data: data, encoding: .utf8) else {
            print("[Suggestions] Failed to decode response as UTF-8")
            return []
        }
        print("[Suggestions] Raw prefix: \(raw.prefix(120))")
        // Extract the outermost JSON array — works regardless of callback wrapper name
        guard let arrayStart = raw.firstIndex(of: "["),
              let arrayEnd = raw.lastIndex(of: "]") else {
            print("[Suggestions] Could not find JSON array bounds")
            return []
        }
        let jsonString = String(raw[arrayStart...arrayEnd])
        print("[Suggestions] JSON prefix after strip: \(jsonString.prefix(120))")
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [Any]
        else {
            print("[Suggestions] JSON parse failed")
            return []
        }
        guard let suggestions = json[safe: 1] as? [[Any]] else {
            print("[Suggestions] Unexpected JSON shape: \(json.prefix(2))")
            return []
        }
        let results = suggestions.compactMap { $0[safe: 0] as? String }
        print("[Suggestions] Parsed \(results.count) suggestions: \(results.prefix(5))")
        return results
    }

    // MARK: - Shorts

    public func fetchShorts() async throws -> VideoGroup {
        // Mirrors fetchHome(): use postTV (TV client + Bearer auth, youtubei.googleapis.com)
        // when a token is available — the same client that successfully returns home/subs.
        // Without auth, fall back to postTVCategory (TV client, www.youtube.com), then
        // the WEB client, then a "#shorts" search as a last resort.
        let isAuth = authToken != nil
        tubeLog.notice("fetchShorts: isAuth=\(isAuth, privacy: .public)")

        // Strategy 1 (authenticated): postTV — mirrors fetchHome/fetchSubscriptions
        if isAuth {
            do {
                var body = makeBody(client: tvClientContext)
                body["browseId"] = "FEshorts"
                let data = try await postTV(endpoint: "browse", body: body)
                let group = try parseVideoGroup(from: data, title: "Shorts")
                let shorts = group.videos.filter { $0.isShort }
                let token = group.nextPageToken.map { String($0.prefix(16)) + "…" } ?? "nil"
                tubeLog.notice("fetchShorts postTV → \(group.videos.count, privacy: .public) videos, \(shorts.count, privacy: .public) shorts, token=\(token, privacy: .public)")
                if !shorts.isEmpty {
                    return VideoGroup(title: "Shorts", videos: shorts, nextPageToken: group.nextPageToken)
                }
                tubeLog.notice("fetchShorts postTV returned 0 shorts — trying postTVCategory")
            } catch {
                tubeLog.notice("fetchShorts postTV failed (\(error, privacy: .public)) — trying postTVCategory")
            }
        }

        // Strategy 2: postTVCategory (TV client, www.youtube.com, no auth)
        do {
            var body = makeBody(client: tvClientContext)
            body["browseId"] = "FEshorts"
            let data = try await postTVCategory(endpoint: "browse", body: body)
            let group = try parseVideoGroup(from: data, title: "Shorts")
            let shorts = group.videos.filter { $0.isShort }
            let token = group.nextPageToken.map { String($0.prefix(16)) + "…" } ?? "nil"
            tubeLog.notice("fetchShorts postTVCategory → \(group.videos.count, privacy: .public) videos, \(shorts.count, privacy: .public) shorts, token=\(token, privacy: .public)")
            if !shorts.isEmpty {
                return VideoGroup(title: "Shorts", videos: shorts, nextPageToken: group.nextPageToken)
            }
            tubeLog.notice("fetchShorts postTVCategory returned 0 shorts — trying WEB client")
        } catch {
            tubeLog.notice("fetchShorts postTVCategory failed (\(error, privacy: .public)) — trying WEB client")
        }

        // Strategy 3: WEB client (www.youtube.com) — returns richGridRenderer →
        // richItemRenderer → reelItemRenderer which parseVideoGroup handles.
        do {
            var body = makeBody(client: webClientContext)
            body["browseId"] = "FEshorts"
            let data = try await post(endpoint: "browse", body: body)
            let group = try parseVideoGroup(from: data, title: "Shorts")
            let shorts = group.videos.filter { $0.isShort }
            let token = group.nextPageToken.map { String($0.prefix(16)) + "…" } ?? "nil"
            tubeLog.notice("fetchShorts WEB → \(group.videos.count, privacy: .public) videos, \(shorts.count, privacy: .public) shorts, token=\(token, privacy: .public)")
            if !shorts.isEmpty {
                return VideoGroup(title: "Shorts", videos: shorts, nextPageToken: group.nextPageToken)
            }
            tubeLog.notice("fetchShorts WEB returned 0 shorts — falling back to search")
        } catch {
            tubeLog.notice("fetchShorts WEB failed (\(error, privacy: .public)) — falling back to search")
        }

        // Strategy 4 (last resort): search "#shorts".
        let searchGroup = try await search(query: "#shorts")
        let shorts = searchGroup.videos.filter { $0.isShort }
        tubeLog.notice("fetchShorts search → \(searchGroup.videos.count, privacy: .public) total, \(shorts.count, privacy: .public) shorts, token=\(searchGroup.nextPageToken.map { String($0.prefix(16)) + "\u{2026}" } ?? "nil", privacy: .public)")
        return VideoGroup(title: "Shorts", videos: shorts, nextPageToken: searchGroup.nextPageToken)
    }

    public func fetchShortsMore(continuationToken: String) async throws -> VideoGroup {
        // Mirrors fetchShorts: try postTV first (for tokens issued by postTV), then
        // postTVCategory, then WEB — so the right host/auth combination is always used.
        tubeLog.notice("fetchShortsMore token=\(continuationToken.prefix(16), privacy: .public)…")
        let isAuth = authToken != nil

        if isAuth {
            do {
                let body = makeBody(client: tvClientContext, continuationToken: continuationToken)
                let data = try await postTV(endpoint: "browse", body: body)
                let group = try parseVideoGroup(from: data, title: "Shorts")
                let shorts = group.videos.filter { $0.isShort }
                let token = group.nextPageToken.map { String($0.prefix(16)) + "…" } ?? "nil"
                tubeLog.notice("fetchShortsMore postTV → \(group.videos.count, privacy: .public) videos, \(shorts.count, privacy: .public) shorts, token=\(token, privacy: .public)")
                if !group.videos.isEmpty {
                    return VideoGroup(title: "Shorts", videos: shorts, nextPageToken: group.nextPageToken)
                }
            } catch {
                tubeLog.notice("fetchShortsMore postTV failed (\(error, privacy: .public)) — trying postTVCategory")
            }
        }

        do {
            let body = makeBody(client: tvClientContext, continuationToken: continuationToken)
            let data = try await postTVCategory(endpoint: "browse", body: body)
            let group = try parseVideoGroup(from: data, title: "Shorts")
            let shorts = group.videos.filter { $0.isShort }
            let token = group.nextPageToken.map { String($0.prefix(16)) + "…" } ?? "nil"
            tubeLog.notice("fetchShortsMore postTVCategory → \(group.videos.count, privacy: .public) videos, \(shorts.count, privacy: .public) shorts, token=\(token, privacy: .public)")
            if !group.videos.isEmpty {
                return VideoGroup(title: "Shorts", videos: shorts, nextPageToken: group.nextPageToken)
            }
        } catch {
            tubeLog.notice("fetchShortsMore postTVCategory failed (\(error, privacy: .public)) — trying WEB")
        }

        do {
            let body = makeBody(client: webClientContext, continuationToken: continuationToken)
            let data = try await post(endpoint: "browse", body: body)
            let group = try parseVideoGroup(from: data, title: "Shorts")
            let shorts = group.videos.filter { $0.isShort }
            let token = group.nextPageToken.map { String($0.prefix(16)) + "\u{2026}" } ?? "nil"
            tubeLog.notice("fetchShortsMore WEB → \(group.videos.count, privacy: .public) videos, \(shorts.count, privacy: .public) shorts, token=\(token, privacy: .public)")
            if !group.videos.isEmpty {
                return VideoGroup(title: "Shorts", videos: shorts, nextPageToken: group.nextPageToken)
            }
        } catch {
            tubeLog.notice("fetchShortsMore WEB failed (\(error, privacy: .public)) — trying search continuation")
        }

        // Last resort: search continuation token (issued when fetchShorts fell back to strategy 4).
        let searchGroup = try await search(query: "#shorts", continuationToken: continuationToken)
        let searchShorts = searchGroup.videos.filter { $0.isShort }
        let searchToken = searchGroup.nextPageToken.map { String($0.prefix(16)) + "\u{2026}" } ?? "nil"
        tubeLog.notice("fetchShortsMore search → \(searchGroup.videos.count, privacy: .public) total, \(searchShorts.count, privacy: .public) shorts, token=\(searchToken, privacy: .public)")
        return VideoGroup(title: "Shorts", videos: searchShorts, nextPageToken: searchGroup.nextPageToken)
    }

    // MARK: - Category sections

    public func fetchMusic() async throws -> VideoGroup {
        do {
            // FEmusic_home is the TVHTML5 browse ID for the music category page.
            var body = makeBody(client: tvClientContext)
            body["browseId"] = "FEmusic_home"
            let data = try await postTVCategory(endpoint: "browse", body: body)
            let group = try parseVideoGroup(from: data, title: "Music")
            if !group.videos.isEmpty { return group }
        } catch {
            tubeLog.notice("fetchMusic browse failed, falling back to search: \(error, privacy: .public)")
        }
        return try await search(query: "music")
    }

    public func fetchGaming() async throws -> VideoGroup {
        do {
            // FEgaming requires TVHTML5 context on www.youtube.com (not googleapis.com).
            var body = makeBody(client: tvClientContext)
            body["browseId"] = "FEgaming"
            let data = try await postTVCategory(endpoint: "browse", body: body)
            let group = try parseVideoGroup(from: data, title: "Gaming")
            if !group.videos.isEmpty { return group }
        } catch {
            tubeLog.notice("fetchGaming browse failed, falling back to search: \(error, privacy: .public)")
        }
        return try await search(query: "gaming")
    }

    public func fetchNews() async throws -> VideoGroup {
        // FEnews is not a valid InnerTube browse ID — use search directly.
        return try await search(query: "news today")
    }

    public func fetchLive() async throws -> VideoGroup {
        do {
            var body = makeBody(client: tvClientContext)
            body["browseId"] = "FElive_home"
            let data = try await postTVCategory(endpoint: "browse", body: body)
            let group = try parseVideoGroup(from: data, title: "Live")
            if !group.videos.isEmpty { return group }
        } catch {
            tubeLog.notice("fetchLive browse failed, falling back to search: \(error, privacy: .public)")
        }
        return try await search(query: "live stream")
    }

    public func fetchSports() async throws -> VideoGroup {
        do {
            // FEsportsau is the known TVHTML5 browse ID for the sports category.
            var body = makeBody(client: tvClientContext)
            body["browseId"] = "FEsportsau"
            let data = try await postTVCategory(endpoint: "browse", body: body)
            let group = try parseVideoGroup(from: data, title: "Sports")
            if !group.videos.isEmpty { return group }
        } catch {
            tubeLog.notice("fetchSports browse failed, falling back to search: \(error, privacy: .public)")
        }
        return try await search(query: "sports")
    }
}
