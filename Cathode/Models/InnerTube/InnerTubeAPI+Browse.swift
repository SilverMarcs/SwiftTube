import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

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

    public func fetchHome(continuationToken: String? = nil) async throws -> VideoGroup {
        let isAuth = authToken != nil
        if !isAuth {
            return try await search(query: "trending", continuationToken: continuationToken)
        }
        
        var body = makeBody(client: tvClientContext,
                            continuationToken: continuationToken,
                            includeVisitorData: true)
        if continuationToken == nil {
            body["browseId"] = "FEwhat_to_watch"
        }
        let data = try await postTV(endpoint: "browse", body: body)
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
        return rows
    }

    public func fetchAllRecommendations(maxPages: Int = 5) async throws -> [Video] {
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

    /// Pages the home feed as named shelves (one `.row` VideoGroup each) and
    /// concatenates them, preserving shelf order. The page-level continuation is
    /// carried on the last shelf's `nextPageToken` (set by `parseVideoGroupRows`);
    /// paging stops when a page yields no shelves or no further token.
    public func fetchAllRecommendationRows(maxPages: Int = 6) async throws -> [VideoGroup] {
        var all: [VideoGroup] = []
        var token: String? = nil
        for _ in 0..<maxPages {
            let rows = try await fetchHomeRows(continuationToken: token)
            guard !rows.isEmpty else { break }
            all.append(contentsOf: rows)
            guard let next = rows.last?.nextPageToken, !next.isEmpty else { break }
            token = next
        }
        return all
    }

    /// Loads MORE items for a single home shelf via its horizontal continuation
    /// token. Uses the generic flat parser, which walks tileRenderers and captures
    /// the next continuation regardless of the continuation wrapper's exact key.
    /// Only `.videos` and `.nextPageToken` (the shelf's next token) are meaningful here.
    public func fetchHomeShelfContinuation(continuationToken: String) async throws -> VideoGroup {
        let body = makeBody(client: tvClientContext, continuationToken: continuationToken)
        let data = try await postTV(endpoint: "browse", body: body)
        return try parseVideoGroup(from: data, title: nil)
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

    // Shorts feed lives in InnerTubeAPI+Shorts.swift (personalised home shelf +
    // reel_watch_sequence). FEshorts is dead (HTTP 400 on every client).

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
        }
        return try await search(query: "sports")
    }
}
