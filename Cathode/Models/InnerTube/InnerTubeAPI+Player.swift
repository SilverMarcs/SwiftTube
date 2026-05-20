import Foundation
import os
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private let tubeLog = Logger(subsystem: appSubsystem, category: "InnerTube")

// MARK: - Player endpoints and playback tracking

extension InnerTubeAPI {

    // MARK: - Player stream URLs

    public func fetchPlayerInfo(videoId: String) async throws -> PlayerInfo {
        // Refresh poToken if a provider is configured and the current token doesn't cover this videoId.
        if let provider = poTokenProvider, poToken == nil || poTokenVideoId != videoId {
            if let token = try? await provider.token(for: videoId) {
                poToken = token
                poTokenVideoId = videoId
                poTokenExpiry = Date().addingTimeInterval(6 * 3600)
            }
        }
        var body = makeBody(client: iosClientContext, includePoToken: true)
        body["videoId"] = videoId
        body["racyCheckOk"] = true
        body["contentCheckOk"] = true
        let data = try await postPlayer(body: body)
        var info = try parsePlayerInfo(from: data, videoId: videoId)
        // Append &pot= to CDN URLs if we have a valid token.
        if let pot = poToken, poTokenVideoId == videoId {
            info = info.applyingPoToken(pot)
        }
        return info
    }

    /// Fetches player info using the Web client, which returns muxed (video+audio)
    /// MP4 streams suitable for direct file download and saving to Photos.
    /// The iOS client only returns adaptive-only streams; the Web client includes
    /// itag 18 (360p muxed) and itag 22 (720p muxed) in the `formats` array.
    public func fetchPlayerInfoForDownload(videoId: String) async throws -> PlayerInfo {
        var body = makeBody(client: webClientContext)
        body["videoId"] = videoId
        body["racyCheckOk"] = true
        body["contentCheckOk"] = true
        let data = try await post(endpoint: "player", body: body)
        return try parsePlayerInfo(from: data, videoId: videoId)
    }

    /// Fetches player info using the Android client.
    /// Used as the primary download fallback: Android CDN URLs are signed with
    /// `c=ANDROID` and are reliably downloadable with a standard Android UA.
    /// Unlike TVHTML5-signed URLs, these do not require session cookies.
    public func fetchPlayerInfoAndroid(videoId: String) async throws -> PlayerInfo {
        var body = makeBody(client: androidClientContext)
        body["videoId"] = videoId
        body["racyCheckOk"] = true
        body["contentCheckOk"] = true
        let data = try await postAndroid(endpoint: "player", body: body)
        return try parsePlayerInfo(from: data, videoId: videoId)
    }

    /// Fetches player info using the Android VR (Oculus) client.
    /// Used as a fallback in audio-only mode when the iOS client audio URL is inaccessible.
    /// Per yt-dlp (May 2026), this client does not require a PO token for adaptive audio.
    public func fetchPlayerInfoAndroidVR(videoId: String) async throws -> PlayerInfo {
        var body = makeBody(client: androidVRClientContext)
        body["videoId"] = videoId
        body["racyCheckOk"] = true
        body["contentCheckOk"] = true
        let data = try await post(endpoint: "player", body: body)
        return try parsePlayerInfo(from: data, videoId: videoId)
    }

    /// Fetches player info using the authenticated TV client.
    /// Used as a fallback when the anonymous Web client returns UNPLAYABLE —
    /// membership-only, age-restricted, or subscription-paywalled videos require auth.
    public func fetchPlayerInfoAuthenticated(videoId: String) async throws -> PlayerInfo {
        var body = makeBody(client: tvClientContext)
        body["videoId"] = videoId
        body["racyCheckOk"] = true
        body["contentCheckOk"] = true
        let data = try await postTV(endpoint: "player", body: body)
        return try parsePlayerInfo(from: data, videoId: videoId)
    }

    /// Fetches end-screen cards for a video using the Web client.
    /// The iOS player client typically omits `endscreen` data; the Web client reliably includes it.
    /// Returns an empty array if no end cards are available or the request fails.
    public func fetchEndCards(videoId: String) async throws -> [EndCard] {
        var body = makeBody(client: webClientContext)
        body["videoId"] = videoId
        body["racyCheckOk"] = true
        body["contentCheckOk"] = true
        let data = try await post(endpoint: "player", body: body)
        let cards = parseEndCards(from: data)
        tubeLog.notice("fetchEndCards id=\(videoId, privacy: .public) → \(cards.count, privacy: .public) cards")
        return cards
    }

    // MARK: - Playback Tracking (Watch History)

    /// Generates a Client Playback Nonce (CPN) — a random 16-character base64url string.
    /// YouTube uses this to attribute a view to an account and record it in watch history.
    /// Must be generated once per playback session and used in every tracking ping.
    public static func generateCPN() -> String {
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
        let chars = Array(alphabet)
        return String((0..<16).map { _ in chars[Int.random(in: 0..<chars.count)] })
    }

    /// Fires `videostatsPlaybackUrl` to record the video start in the user's YouTube watch history.
    /// Must be called once when AVPlayerItem becomes `readyToPlay`.
    /// Mirrors Android's `VideoStateController` stats-ping behaviour in MediaServiceCore.
    /// - Parameters:
    ///   - videoId: The YouTube video ID being watched.
    ///   - cpn: The Client Playback Nonce for this session (see `generateCPN()`).
    ///   - trackingURLs: Tracking URLs from the player response; if nil, falls back to constructed URLs.
    public func reportPlaybackStarted(videoId: String, cpn: String, trackingURLs: PlaybackTrackingURLs?) async {
        let url = trackingURLs?.playbackURL ?? Self.fallbackPlaybackURL(videoId: videoId)
        let extraParams: [String: String] = [
            "ver":   "2",
            "cpn":   cpn,
            "docid": videoId,
            "cmt":   "0",
        ]
        await pingTrackingURL(url, extraParams: extraParams)
        tubeLog.notice("reportPlaybackStarted: videoId=\(videoId, privacy: .public) cpn=\(cpn.prefix(4), privacy: .public)… usedFallback=\(trackingURLs == nil, privacy: .public)")
    }

    /// Fires `videostatsWatchtimeUrl` to record a watched interval in the user's YouTube watch history.
    /// Should be called when playback stops/pauses/ends.
    /// - Parameters:
    ///   - videoId: The YouTube video ID being watched.
    ///   - cpn: The same Client Playback Nonce used in `reportPlaybackStarted`.
    ///   - trackingURLs: Tracking URLs from the player response; if nil, falls back to constructed URLs.
    ///   - segmentStart: Playhead position (seconds) when the current play segment began.
    ///   - segmentEnd: Playhead position (seconds) when the current play segment ended (i.e. now).
    public func reportWatchtime(
        videoId: String,
        cpn: String,
        trackingURLs: PlaybackTrackingURLs?,
        segmentStart: TimeInterval,
        segmentEnd: TimeInterval
    ) async {
        let url = trackingURLs?.watchtimeURL ?? Self.fallbackWatchtimeURL(videoId: videoId)
        let extraParams: [String: String] = [
            "ver":   "2",
            "cpn":   cpn,
            "docid": videoId,
            "cmt":   String(format: "%.3f", segmentEnd),
            "st":    String(format: "%.3f", segmentStart),
            "et":    String(format: "%.3f", segmentEnd),
        ]
        await pingTrackingURL(url, extraParams: extraParams)
        tubeLog.notice("reportWatchtime: videoId=\(videoId, privacy: .public) st=\(Int(segmentStart))s et=\(Int(segmentEnd))s")
    }

    /// Fetches account-bound playback tracking URLs by making an authenticated TV-client
    /// `/player` request. The iOS-client player request (used for HLS stream URLs) is
    /// unauthenticated, so its `playbackTracking` URLs carry no account context. A TV-client
    /// request with the OAuth Bearer token returns URLs that YouTube has pre-bound to the
    /// signed-in account server-side — pinging those URLs records the view in watch history.
    ///
    /// Called in parallel with the primary iOS player fetch; only the tracking URLs are kept.
    public func fetchAuthenticatedTrackingURLs(videoId: String) async -> PlaybackTrackingURLs? {
        guard authToken != nil else { return nil }
        do {
            var body = makeBody(client: tvClientContext)
            body["videoId"] = videoId
            body["racyCheckOk"] = true
            body["contentCheckOk"] = true
            let data = try await postTV(endpoint: "player", body: body)
            guard
                let tracking  = data["playbackTracking"] as? [String: Any],
                let pbStr      = (tracking["videostatsPlaybackUrl"]  as? [String: Any])?["baseUrl"] as? String,
                let wtStr      = (tracking["videostatsWatchtimeUrl"] as? [String: Any])?["baseUrl"] as? String,
                let pbURL      = URL(string: pbStr),
                let wtURL      = URL(string: wtStr)
            else {
                tubeLog.notice("fetchAuthenticatedTrackingURLs: no tracking data in TV player response for \(videoId, privacy: .public)")
                return nil
            }
            tubeLog.notice("fetchAuthenticatedTrackingURLs: account-bound URLs obtained for \(videoId, privacy: .public)")
            return PlaybackTrackingURLs(playbackURL: pbURL, watchtimeURL: wtURL)
        } catch {
            tubeLog.error("fetchAuthenticatedTrackingURLs failed for \(videoId, privacy: .public): \(error, privacy: .public)")
            return nil
        }
    }

    /// Same as `fetchAuthenticatedTrackingURLs(videoId:)` but uses the supplied token directly
    /// instead of reading `self.authToken`. Use this when the caller holds the token but cannot
    /// guarantee that `setAuthToken` has already propagated to the actor (e.g. prefetch tasks
    /// that start before `PlaybackViewModel.updateAuthToken` has had a chance to run).
    public func fetchAuthenticatedTrackingURLs(videoId: String, usingToken token: String) async -> PlaybackTrackingURLs? {
        do {
            var body = makeBody(client: tvClientContext)
            body["videoId"] = videoId
            body["racyCheckOk"] = true
            body["contentCheckOk"] = true
            let data = try await postTV(endpoint: "player", body: body, explicitBearerToken: token)
            guard
                let tracking  = data["playbackTracking"] as? [String: Any],
                let pbStr      = (tracking["videostatsPlaybackUrl"]  as? [String: Any])?["baseUrl"] as? String,
                let wtStr      = (tracking["videostatsWatchtimeUrl"] as? [String: Any])?["baseUrl"] as? String,
                let pbURL      = URL(string: pbStr),
                let wtURL      = URL(string: wtStr)
            else {
                tubeLog.notice("fetchAuthenticatedTrackingURLs: no tracking data in TV player response for \(videoId, privacy: .public)")
                return nil
            }
            tubeLog.notice("fetchAuthenticatedTrackingURLs: account-bound URLs obtained for \(videoId, privacy: .public)")
            return PlaybackTrackingURLs(playbackURL: pbURL, watchtimeURL: wtURL)
        } catch {
            tubeLog.error("fetchAuthenticatedTrackingURLs failed for \(videoId, privacy: .public): \(error, privacy: .public)")
            return nil
        }
    }

    // MARK: - Private player helpers

    private func parsePlayerInfo(from json: [String: Any], videoId: String) throws -> PlayerInfo {
        let videoDetails = json["videoDetails"] as? [String: Any]
        let title = videoDetails?["title"] as? String ?? ""
        let channelTitle = videoDetails?["author"] as? String ?? ""
        let description = videoDetails?["shortDescription"] as? String
        let durationStr = videoDetails?["lengthSeconds"] as? String
        let duration = durationStr.flatMap { Double($0) }
        let isLive = videoDetails?["isLiveContent"] as? Bool ?? false
        let viewCount = (videoDetails?["viewCount"] as? String).flatMap { Int($0) }
        let thumbURL = ((videoDetails?["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]])?
            .last.flatMap { $0["url"] as? String }.flatMap { URL(string: $0) }

        // Stream formats
        let streamingData = json["streamingData"] as? [String: Any]
        let playabilityDict  = json["playabilityStatus"] as? [String: Any]
        let playabilityStatus = playabilityDict?["status"] as? String ?? "unknown"
        let playabilityReason = playabilityDict?["reason"] as? String
            ?? (playabilityDict?["errorScreen"] as? [String: Any])
                .flatMap { ($0["playerErrorMessageRenderer"] as? [String: Any])?["subreason"] as? [String: Any] }
                .flatMap { extractText($0) }
        tubeLog.notice("parsePlayerInfo id=\(videoId, privacy: .public) playability=\(playabilityStatus, privacy: .public) reason=\(playabilityReason ?? "nil", privacy: .public) hasStreamingData=\(streamingData != nil, privacy: .public)")
        // Fail early for definitely-unplayable videos so callers don't waste work on
        // related/SponsorBlock fetches. Mirrors Android playabilityStatus check.
        if streamingData == nil, playabilityStatus != "OK" {
            let reason = playabilityReason ?? "This video is unavailable (\(playabilityStatus))"
            tubeLog.error("❌ parsePlayerInfo: unplayable — \(reason, privacy: .public)")
            // Check for IP-block signals before throwing the generic unavailable error.
            // These keywords indicate YouTube is rejecting the request based on the source
            // IP (VPN/proxy/shared datacenter). Throwing a distinct error type lets callers
            // short-circuit the retry chain and show a targeted message.
            let lower = reason.lowercased()
            let ipBlockKeywords = ["your ip", "ip address", "vpn", "proxy", "bot", "sign in to confirm"]
            if ipBlockKeywords.contains(where: { lower.contains($0) }) {
                throw ITAPIError.ipBlocked(reason)
            }
            throw ITAPIError.unavailable(reason)
        }
        var formats: [VideoFormat] = []

        func parseFormats(_ raw: [[String: Any]]) -> [VideoFormat] {
            raw.compactMap { f -> VideoFormat? in
                guard f["itag"] is Int else { return nil }
                let urlStr = f["url"] as? String
                let url = urlStr.flatMap { URL(string: $0) }
                let quality = f["qualityLabel"] as? String ?? f["quality"] as? String ?? "unknown"
                let mimeType = f["mimeType"] as? String ?? ""
                let width = f["width"] as? Int ?? 0
                let height = f["height"] as? Int ?? 0
                let fps = f["fps"] as? Int ?? 30
                let bitrate = f["bitrate"] as? Int
                return VideoFormat(label: quality, width: width, height: height, fps: fps, mimeType: mimeType, url: url, bitrate: bitrate)
            }
        }

        if let f = streamingData?["formats"] as? [[String: Any]] {
            formats += parseFormats(f)
        }
        if let f = streamingData?["adaptiveFormats"] as? [[String: Any]] {
            formats += parseFormats(f)
        }
        // Remove exact-duplicate entries that appear when a video has many audio tracks
        // (e.g. multi-language uploads return the same itag repeated for each language
        // variant, all with distinct URLs). Keep unique by URL string; fall back to
        // index-based dedup for formats without a URL.
        var seen = Set<String>()
        formats = formats.filter { fmt in
            let key = fmt.url?.absoluteString ?? "\(fmt.mimeType)-\(fmt.label)-\(fmt.bitrate ?? 0)"
            return seen.insert(key).inserted
        }

        let hlsURL = (streamingData?["hlsManifestUrl"] as? String).flatMap { URL(string: $0) }
        let dashURL = (streamingData?["dashManifestUrl"] as? String).flatMap { URL(string: $0) }

        // Captions — parse from captions.playerCaptionsTracklistRenderer.captionTracks
        let captionTracks: [CaptionTrack] = {
            guard let trackList = (json["captions"] as? [String: Any])
                .flatMap({ $0["playerCaptionsTracklistRenderer"] as? [String: Any] })
                .flatMap({ $0["captionTracks"] as? [[String: Any]] })
            else { return [] }
            return trackList.compactMap { track -> CaptionTrack? in
                guard let baseUrlStr = track["baseUrl"] as? String,
                      let rawURL = URL(string: baseUrlStr) else { return nil }
                // Force WebVTT format by appending fmt=vtt to the base URL
                var comps = URLComponents(url: rawURL, resolvingAgainstBaseURL: false)
                var items = comps?.queryItems ?? []
                items.removeAll { $0.name == "fmt" }
                items.append(URLQueryItem(name: "fmt", value: "vtt"))
                comps?.queryItems = items
                guard let baseURL = comps?.url else { return nil }
                let languageCode = track["languageCode"] as? String ?? ""
                let name = (track["name"] as? [String: Any]).flatMap { extractText($0) }
                    ?? (track["nameTranslated"] as? [String: Any]).flatMap { extractText($0) }
                    ?? languageCode
                let vssId = track["vssId"] as? String ?? ""
                let kind = track["kind"] as? String ?? ""
                let isAuto = vssId.hasPrefix("a.") || kind == "asr"
                let trackId = vssId.isEmpty ? languageCode : vssId
                return CaptionTrack(id: trackId, baseURL: baseURL, name: name, languageCode: languageCode, isAutoGenerated: isAuto)
            }
        }()
        tubeLog.notice("parsePlayerInfo: captionTracks=\(captionTracks.count, privacy: .public)")

        // Playback tracking — parse the stat URLs that must be pinged to record
        // the view in YouTube's official watch history.
        // Shape: playbackTracking.videostatsPlaybackUrl.baseUrl (String)
        //        playbackTracking.videostatsWatchtimeUrl.baseUrl (String)
        let trackingURLs: PlaybackTrackingURLs? = {
            guard let tracking = json["playbackTracking"] as? [String: Any],
                  let playbackStr = (tracking["videostatsPlaybackUrl"] as? [String: Any])?["baseUrl"] as? String,
                  let watchtimeStr = (tracking["videostatsWatchtimeUrl"] as? [String: Any])?["baseUrl"] as? String,
                  let playbackURL = URL(string: playbackStr),
                  let watchtimeURL = URL(string: watchtimeStr)
            else {
                tubeLog.notice("parsePlayerInfo: no playbackTracking URLs in response")
                return nil
            }
            tubeLog.notice("parsePlayerInfo: got playbackTracking URLs")
            return PlaybackTrackingURLs(playbackURL: playbackURL, watchtimeURL: watchtimeURL)
        }()

        let video = ITVideo(
            id: videoId,
            title: title,
            channelTitle: channelTitle,
            description: description,
            thumbnailURL: thumbURL,
            duration: duration,
            viewCount: viewCount,
            isLive: isLive
        )

        guard hlsURL != nil || !formats.isEmpty else {
            throw ITAPIError.unavailable("This video is unavailable")
        }
        // If streamingData is present but every format URL is nil, the server returned
        // cipher-protected URLs that we cannot decode (signatureCipher / cipher fields).
        // Treat this as unavailable so the caller's fallback chain (Android client) fires
        // rather than surfacing a confusing "No stream URL" decoding error.
        let hasAnyURL = hlsURL != nil || formats.contains { $0.url != nil }
        if !hasAnyURL {
            tubeLog.error("❌ parsePlayerInfo: streamingData present but all format URLs are nil (cipher-protected?)")
            throw ITAPIError.unavailable("Stream URLs require decryption — not supported by this client")
        }
        let endCards = parseEndCards(from: json)
        tubeLog.notice("parsePlayerInfo: endCards=\(endCards.count, privacy: .public)")
        return PlayerInfo(video: video, formats: formats, hlsURL: hlsURL, dashURL: dashURL, captionTracks: captionTracks, trackingURLs: trackingURLs, endCards: endCards)
    }

    // MARK: – End cards parser

    private func parseEndCards(from json: [String: Any]) -> [EndCard] {
        guard let endscreen = (json["endscreen"] as? [String: Any])?["endscreenRenderer"] as? [String: Any],
              let elements = endscreen["elements"] as? [[String: Any]]
        else {
            tubeLog.notice("parseEndCards: no endscreen key in response (normal for iOS client)")
            return []
        }

        return elements.compactMap { element -> EndCard? in
            guard let renderer = element["endscreenElementRenderer"] as? [String: Any] else { return nil }

            let styleRaw = renderer["style"] as? String ?? ""
            let style = EndCard.Style(rawValue: styleRaw) ?? .unknown

            let endpoint = renderer["endpoint"] as? [String: Any]
            let videoId = (endpoint?["watchEndpoint"] as? [String: Any])?["videoId"] as? String

            let title = (renderer["title"] as? [String: Any]).flatMap { extractText($0) } ?? ""

            let thumbnailURL = ((renderer["image"] as? [String: Any])?["thumbnails"] as? [[String: Any]])?
                .last.flatMap { $0["url"] as? String }.flatMap { URL(string: $0) }

            // NSNumber bridges all JSON numbers (int or float). Use .intValue so both
            // integer JSON numbers (e.g. 257357) and float ones (257357.0) are handled.
            // Some API versions return startMs/endMs as quoted strings; fall back to that.
            func parseInt(_ key: String) -> Int {
                if let n = renderer[key] as? NSNumber { return n.intValue }
                if let s = renderer[key] as? String   { return Int(s) ?? 0 }
                return 0
            }

            // Position fields are always floats from the API (0–100 range).
            func parseDouble(_ key: String, default def: Double) -> Double {
                if let n = renderer[key] as? NSNumber { return n.doubleValue }
                return def
            }

            let left        = parseDouble("left",        default: 0)
            let top         = parseDouble("top",         default: 0)
            let width       = parseDouble("width",       default: 20)
            let aspectRatio = parseDouble("aspectRatio", default: 1.7778)
            let startMs     = parseInt("startMs")
            let endMs       = parseInt("endMs")
            let id          = renderer["id"] as? String ?? UUID().uuidString

            tubeLog.notice("endCard id=\(id, privacy: .public) style=\(styleRaw, privacy: .public) videoId=\(videoId ?? "nil", privacy: .public) startMs=\(startMs, privacy: .public) endMs=\(endMs, privacy: .public)")

            return EndCard(
                id: id,
                style: style,
                videoId: videoId,
                title: title,
                thumbnailURL: thumbnailURL,
                left: left,
                top: top,
                width: width,
                aspectRatio: aspectRatio,
                startMs: startMs,
                endMs: endMs
            )
        }
    }

    // MARK: - Tracking URL helpers

    /// Appends extra query parameters to a YouTube stats URL and fires a fire-and-forget GET.
    /// Only adds parameters that are not already present in the base URL — preserving
    /// the `cpn`, `docid`, and other session params YouTube embedded in the tracking URL.
    private func pingTrackingURL(_ baseURL: URL, extraParams: [String: String]) async {
        var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        var items = comps?.queryItems ?? []
        for (key, value) in extraParams {
            // Preserve params already in the base URL (e.g. cpn, docid, ver that
            // YouTube's stats server embedded and validates). Only append missing ones.
            if !items.contains(where: { $0.name == key }) {
                items.append(URLQueryItem(name: key, value: value))
            }
        }
        comps?.queryItems = items
        guard let url = comps?.url else {
            tubeLog.error("pingTrackingURL: failed to build URL from \(baseURL, privacy: .public)")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(iosUserAgent, forHTTPHeaderField: "User-Agent")
        // Auth header is required — without it YouTube treats the ping as anonymous
        // and does not record the view in the account's watch history.
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        // BUG-006 fix: log errors and retry once for transient failures instead of silently discarding.
        do {
            let (_, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                tubeLog.warning("pingTrackingURL: HTTP \(http.statusCode) for \(url.absoluteString.prefix(120), privacy: .public)")
            }
        } catch is CancellationError {
            // Task was cancelled (user navigated away) — expected, do not retry.
        } catch {
            tubeLog.warning("pingTrackingURL: transient error (\(error.localizedDescription, privacy: .public)) — retrying once")
            do {
                let (_, response) = try await session.data(for: request)
                if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                    tubeLog.error("pingTrackingURL: retry HTTP \(http.statusCode) for \(url.absoluteString.prefix(120), privacy: .public)")
                }
            } catch {
                tubeLog.error("pingTrackingURL: retry also failed — \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Constructs a fallback playback stats URL for when the player response omits `playbackTracking`.
    /// Matches the pattern used by YouTube.js and Android MediaServiceCore.
    private static func fallbackPlaybackURL(videoId: String) -> URL {
        var comps = URLComponents(string: "https://www.youtube.com/api/stats/playback")!
        comps.queryItems = [
            URLQueryItem(name: "ns",    value: "yt"),
            URLQueryItem(name: "el",    value: "detailpage"),
            URLQueryItem(name: "docid", value: videoId),
        ]
        return comps.url!
    }

    /// Constructs a fallback watchtime stats URL for when the player response omits `playbackTracking`.
    private static func fallbackWatchtimeURL(videoId: String) -> URL {
        var comps = URLComponents(string: "https://www.youtube.com/api/stats/watchtime")!
        comps.queryItems = [
            URLQueryItem(name: "ns",    value: "yt"),
            URLQueryItem(name: "el",    value: "detailpage"),
            URLQueryItem(name: "docid", value: videoId),
        ]
        return comps.url!
    }
}
