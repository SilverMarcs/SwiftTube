import Foundation
import os

private let tubeLog = Logger(subsystem: appSubsystem, category: "InnerTube")

// MARK: - Channel endpoints

extension InnerTubeAPI {

    public func fetchChannel(channelId: String) async throws -> (channel: Channel, videos: VideoGroup) {
        // @handle strings are not valid browseIds — resolve to the real UC… channel ID first.
        let resolvedId: String
        if channelId.hasPrefix("@") {
            tubeLog.notice("fetchChannel resolving handle \(channelId, privacy: .public)")
            resolvedId = try await resolveChannelHandle(channelId)
            tubeLog.notice("fetchChannel resolved \(channelId, privacy: .public) → \(resolvedId, privacy: .public)")
        } else {
            resolvedId = channelId
        }
        var body = makeBody(client: webClientContext)
        body["browseId"] = resolvedId
        tubeLog.notice("fetchChannel browseId=\(resolvedId, privacy: .public)")
        let data = try await post(endpoint: "browse", body: body)
        return try parseChannel(from: data, channelId: resolvedId)
    }

    /// Lightweight channel thumbnail fetch.
    /// Requests the About tab (params `EgVhYm91dA==`) which returns only channel
    /// metadata (no video grid), making the response much smaller than a full channel page.
    /// Used by BrowseViewModel.enrichChannelAvatars() to patch avatar URLs into the
    /// channel list after the initial fast tile-based load.
    public func fetchChannelThumbnailURL(channelId: String) async throws -> URL? {
        try await fetchChannelInfo(channelId: channelId).thumbnailURL
    }

    /// Lightweight channel header fetch (avatar + subscriber count + description),
    /// without loading the video grid. Uses the About tab params.
    public func fetchChannelInfo(channelId: String) async throws -> Channel {
        let resolvedId: String
        if channelId.hasPrefix("@") {
            resolvedId = try await resolveChannelHandle(channelId)
        } else {
            resolvedId = channelId
        }
        var body = makeBody(client: webClientContext)
        body["browseId"] = resolvedId
        body["params"] = "EgVhYm91dA=="  // About tab — header only, no video grid
        let data = try await post(endpoint: "browse", body: body)
        let (channel, _) = try parseChannel(from: data, channelId: resolvedId)
        return channel
    }

    public func fetchChannelVideos(channelId: String, continuationToken: String? = nil) async throws -> VideoGroup {
        var body = makeBody(client: webClientContext, continuationToken: continuationToken)
        if continuationToken == nil {
            body["browseId"] = channelId
            body["params"] = "EgZ2aWRlb3PyBgQKAjoA"  // "Videos" tab parameter
        }
        let videosParams = (body["params"] as? String) ?? "nil"
        tubeLog.notice("fetchChannelVideos browseId=\(channelId, privacy: .public) hasContinuation=\(continuationToken != nil, privacy: .public) params=\(videosParams, privacy: .public)")
        let data = try await post(endpoint: "browse", body: body)
        return try parseVideoGroup(from: data, title: nil)
    }

    public func searchChannels(query: String) async throws -> [Channel] {
        var body = makeBody(client: webClientContext)
        body["query"] = query
        if let params = SearchFilter(type: .channel).encodedParams() {
            body["params"] = params
        }
        let data = try await post(endpoint: "search", body: body)
        return parseChannelRenderers(from: data)
    }

    // MARK: - Private channel helpers

    /// Resolves a YouTube `@handle` to the canonical `UC…` channel ID using the
    /// InnerTube `navigation/resolve_url` endpoint.
    private func resolveChannelHandle(_ handle: String) async throws -> String {
        let handleURL = "https://www.youtube.com/\(handle)"
        var body = makeBody(client: webClientContext)
        body["url"] = handleURL
        tubeLog.notice("resolveChannelHandle url=\(handleURL, privacy: .public)")
        let data = try await post(endpoint: "navigation/resolve_url", body: body)
        // Response shape: { "endpoint": { "browseEndpoint": { "browseId": "UCxxx" } } }
        let endpoint = data["endpoint"] as? [String: Any]
        if let browseId = (endpoint?["browseEndpoint"] as? [String: Any])?["browseId"] as? String {
            return browseId
        }
        let topKeys = data.keys.joined(separator: ", ")
        tubeLog.error("resolveChannelHandle: unexpected response keys=[\(topKeys, privacy: .public)]")
        throw ITAPIError.decodingError("Could not resolve handle \(handle) to a channel ID")
    }

    private func parseChannel(from json: [String: Any], channelId: String) throws -> (Channel, VideoGroup) {
        let headerDict = json["header"] as? [String: Any]
        tubeLog.notice("parseChannel header keys=[\((headerDict?.keys.joined(separator: ",")) ?? "nil", privacy: .public)]")
        let header = headerDict?["c4TabbedHeaderRenderer"] as? [String: Any]
            ?? headerDict?["pageHeaderRenderer"] as? [String: Any]
        let title = header.flatMap { $0["title"] as? String }
            ?? (header?["pageTitle"] as? String)
            ?? {
                // pageHeaderRenderer uses content.pageHeaderViewModel.title.content
                if let content = (header?["content"] as? [String: Any])?["pageHeaderViewModel"] as? [String: Any] {
                    return (content["title"] as? [String: Any]).flatMap { extractText($0) }
                        ?? content["title"] as? String
                }
                return nil
            }()
            ?? ""
        tubeLog.notice("parseChannel header=\(header != nil ? "found" : "nil", privacy: .public) title='\(title, privacy: .public)'")
        let description = header
            .flatMap { $0["description"] as? [String: Any] }
            .flatMap { extractText($0) }
        // avatar: c4TabbedHeaderRenderer uses avatar.thumbnails, pageHeaderRenderer uses banner or content avatar
        let thumbURL: URL? = {
            // c4TabbedHeaderRenderer path
            if let urlStr = ((header?["avatar"] as? [String: Any])?["thumbnails"] as? [[String: Any]])?
                .last.flatMap({ $0["url"] as? String }) {
                return normalizeThumbURL(urlStr)
            }
            // pageHeaderViewModel path: content.pageHeaderViewModel.image.decoratedAvatarViewModel.avatar.avatarViewModel.image.sources
            if let hvm = (header?["content"] as? [String: Any])?["pageHeaderViewModel"] as? [String: Any],
               let sources = ((((hvm["image"] as? [String: Any])?["decoratedAvatarViewModel"] as? [String: Any])?["avatar"] as? [String: Any])?["avatarViewModel"] as? [String: Any])?["image"] as? [String: Any],
               let urlStr = (sources["sources"] as? [[String: Any]])?.last?["url"] as? String {
                return normalizeThumbURL(urlStr)
            }
            // metadata fallback: json.metadata.channelMetadataRenderer.avatar.thumbnails
            if let urlStr = (((json["metadata"] as? [String: Any])?["channelMetadataRenderer"] as? [String: Any])?["avatar"] as? [String: Any]).flatMap({ ($0["thumbnails"] as? [[String: Any]])?.last?["url"] as? String }) {
                return normalizeThumbURL(urlStr)
            }
            return nil
        }()
        let subscribers = header.flatMap { $0["subscriberCountText"] as? [String: Any] }.flatMap { extractText($0) }

        let channel = Channel(
            id: channelId,
            title: title,
            description: description,
            thumbnailURL: thumbURL,
            subscriberCount: subscribers
        )
        let videoGroup = try parseVideoGroup(from: json, title: title)
        return (channel, videoGroup)
    }

    // MARK: – Channel renderer parser (TV/WEB client subscriptions "Channels" tab)
    //
    // Handles channelRenderer, gridChannelRenderer, compactChannelRenderer, and
    // TVHTML5 tileRenderer with TILE_CONTENT_TYPE_CHANNEL.
    private func parseChannelRenderers(from json: [String: Any]) -> [Channel] {
        var channels: [Channel] = []
        var seen = Set<String>()
        // Collect all distinct renderer key names encountered for diagnostics
        var encounteredRendererKeys = Set<String>()

        func extractChannel(from renderer: [String: Any]) -> Channel? {
            // channelId: direct "channelId" key, or from navigationEndpoint.browseEndpoint.browseId
            let channelId: String? = renderer["channelId"] as? String
                ?? (renderer["navigationEndpoint"] as? [String: Any])
                    .flatMap { ($0["browseEndpoint"] as? [String: Any])?["browseId"] as? String }
            guard let channelId, !channelId.isEmpty else { return nil }

            let title = (renderer["title"] as? [String: Any]).flatMap { extractText($0) }
                ?? renderer["title"] as? String
                ?? ""

            // Avatars: channelRenderer uses "thumbnail"; gridChannelRenderer may use
            // "thumbnail" or "channelThumbnailSupportedRenderers.channelThumbnailRenderer.thumbnail"
            let primaryThumb = (renderer["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]]
            let ctsr = (renderer["channelThumbnailSupportedRenderers"] as? [String: Any])?["channelThumbnailRenderer"] as? [String: Any]
            let secondaryThumb = (ctsr?["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]]
            let thumbSources: [[String: Any]]? = primaryThumb ?? secondaryThumb
            let thumbURL = thumbSources?.last.flatMap { $0["url"] as? String }.flatMap { normalizeThumbURL($0) }

            let subscriberCount = (renderer["subscriberCountText"] as? [String: Any])
                .flatMap { extractText($0) }
                ?? (renderer["videoCountText"] as? [String: Any]).flatMap { extractText($0) }

            return Channel(
                id: channelId,
                title: title,
                thumbnailURL: thumbURL,
                subscriberCount: subscriberCount
            )
        }

        func extractChannelFromTile(_ tile: [String: Any]) -> Channel? {
            guard (tile["contentType"] as? String) == "TILE_CONTENT_TYPE_CHANNEL" else { return nil }
            let onSelectCommand = tile["onSelectCommand"] as? [String: Any]
            let channelId: String? = (onSelectCommand?["browseEndpoint"] as? [String: Any])?["browseId"] as? String
                ?? (onSelectCommand?["innertubeCommand"] as? [String: Any])
                    .flatMap { ($0["browseEndpoint"] as? [String: Any])?["browseId"] as? String }
            guard let channelId, !channelId.isEmpty else { return nil }
            let tileMetadata = (tile["metadata"] as? [String: Any])?["tileMetadataRenderer"] as? [String: Any]
            let title = (tileMetadata?["title"] as? [String: Any]).flatMap { extractText($0) } ?? ""
            let tileHeader = (tile["header"] as? [String: Any])?["tileHeaderRenderer"] as? [String: Any]
            let thumbURL = ((tileHeader?["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]])?
                .last.flatMap { $0["url"] as? String }.flatMap { normalizeThumbURL($0) }
            return Channel(id: channelId, title: title, thumbnailURL: thumbURL)
        }

        var avatarLockupDumped = false
        var notificationDumped = false

        func walk(_ obj: Any, depth: Int = 0) {
            guard depth < 50 else {
                tubeLog.warning("parseChannelRenderers: walk depth limit (50) reached — skipping subtree")
                return
            }
            if let dict = obj as? [String: Any] {
                // Track all "xxxRenderer" keys at this level for diagnostics
                for k in dict.keys where k.hasSuffix("Renderer") || k.hasSuffix("ViewModel") {
                    encounteredRendererKeys.insert(k)
                }
                // Dump the first avatarLockupRenderer that actually has a navigationEndpoint (i.e. is a channel, not a sort header)
                if !avatarLockupDumped, let lockup = dict["avatarLockupRenderer"] as? [String: Any],
                   lockup["navigationEndpoint"] != nil {
                    avatarLockupDumped = true
                    if let data = try? JSONSerialization.data(withJSONObject: lockup, options: [.sortedKeys]),
                       let str = String(data: data, encoding: .utf8) {
                        tubeLog.notice("avatarLockupRenderer (with nav) JSON: \(String(str.prefix(2000)), privacy: .public)")
                    }
                }
                // Dump the first notificationMultiActionRenderer (these appear per-channel)
                if !notificationDumped, let notif = dict["notificationMultiActionRenderer"] as? [String: Any] {
                    notificationDumped = true
                    if let data = try? JSONSerialization.data(withJSONObject: notif, options: [.sortedKeys]),
                       let str = String(data: data, encoding: .utf8) {
                        tubeLog.notice("notificationMultiActionRenderer JSON: \(String(str.prefix(2000)), privacy: .public)")
                    }
                }
                // TVHTML5 channel tile
                if let tile = dict["tileRenderer"] as? [String: Any],
                   let channel = extractChannelFromTile(tile) {
                    if seen.insert(channel.id).inserted { channels.append(channel) }
                    return
                }
                // WEB channelRenderer / gridChannelRenderer / compactChannelRenderer
                let rendererKeys = ["channelRenderer", "gridChannelRenderer", "compactChannelRenderer"]
                if let key = rendererKeys.first(where: { dict[$0] is [String: Any] }),
                   let renderer = dict[key] as? [String: Any],
                   let channel = extractChannel(from: renderer) {
                    if seen.insert(channel.id).inserted { channels.append(channel) }
                    return
                }
                for value in dict.values { walk(value, depth: depth + 1) }
            } else if let arr = obj as? [Any] {
                for item in arr { walk(item, depth: depth + 1) }
            }
        }

        walk(json)
        let withThumbs = channels.filter { $0.thumbnailURL != nil }.count
        let rendererSample = Array(encounteredRendererKeys.sorted().prefix(12))
        tubeLog.notice("parseChannelRenderers → \(channels.count, privacy: .public) channels, \(withThumbs, privacy: .public) with thumbnail | renderer keys seen: \(rendererSample, privacy: .public)")
        return channels
    }

    // MARK: – Subscribed channels parser (TVHTML5 fallback)
    //
    // Extracts every subscribed channel from a TVHTML5 FEchannels response.
    // Each subscription appears as a `tileRenderer` with `contentType` ==
    // `TILE_CONTENT_TYPE_CHANNEL` and rich metadata (avatar thumbnail, @handle,
    // subscriber count). This is the most complete subscriptions source —
    // `/guide` and FEsubscriptions video-tile parsing miss accounts where the
    // server returns an empty or partial guide.
    func parseChannelsTab(from json: [String: Any]) -> [Channel] {
        var channels: [Channel] = []
        var seen = Set<String>()

        func channelFromTile(_ tile: [String: Any]) -> Channel? {
            guard (tile["contentType"] as? String) == "TILE_CONTENT_TYPE_CHANNEL" else { return nil }
            let channelId: String? = tile["contentId"] as? String
                ?? ((tile["onSelectCommand"] as? [String: Any])?["browseEndpoint"] as? [String: Any])?["browseId"] as? String
            guard let channelId, channelId.hasPrefix("UC") else { return nil }

            let tileMetadata = (tile["metadata"] as? [String: Any])?["tileMetadataRenderer"] as? [String: Any]
            let title = extractText((tileMetadata?["title"] as? [String: Any]) ?? [:]) ?? ""
            // lines[0] → @handle (or whatever the first line is)
            // lines[1] → subscriber count
            let lines = tileMetadata?["lines"] as? [[String: Any]] ?? []
            func lineText(_ index: Int) -> String? {
                guard index < lines.count,
                      let lineRenderer = lines[index]["lineRenderer"] as? [String: Any],
                      let items = lineRenderer["items"] as? [[String: Any]],
                      let firstItem = items.first,
                      let lineItemRenderer = firstItem["lineItemRenderer"] as? [String: Any],
                      let text = lineItemRenderer["text"] as? [String: Any]
                else { return nil }
                return extractText(text)
            }
            let handle = lineText(0).flatMap { s -> String? in
                guard let at = s.firstIndex(of: "@") else { return nil }
                return String(s[at...].components(separatedBy: .whitespacesAndNewlines).first ?? "")
            }
            let subscriberCount = lineText(1)
            // Avatar thumbnail — pick the largest, fall back to none.
            let thumbnails = ((tile["header"] as? [String: Any])?["tileHeaderRenderer"] as? [String: Any])
                .flatMap { ($0["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]] }
            let thumbURL = thumbnails?.last.flatMap { $0["url"] as? String }.flatMap { normalizeThumbURL($0) }

            return Channel(
                id: channelId,
                title: title,
                handle: handle,
                description: nil,
                thumbnailURL: thumbURL,
                subscriberCount: subscriberCount
            )
        }

        func walk(_ obj: Any, depth: Int = 0) {
            guard depth < 50 else { return }
            if let dict = obj as? [String: Any] {
                if let tile = dict["tileRenderer"] as? [String: Any],
                   let channel = channelFromTile(tile) {
                    if seen.insert(channel.id).inserted { channels.append(channel) }
                    return
                }
                for value in dict.values { walk(value, depth: depth + 1) }
            } else if let arr = obj as? [Any] {
                for item in arr { walk(item, depth: depth + 1) }
            }
        }

        walk(json)
        channels.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        return channels
    }

}
