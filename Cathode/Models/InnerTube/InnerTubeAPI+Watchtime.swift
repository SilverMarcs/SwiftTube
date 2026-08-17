//
//  InnerTubeAPI+Watchtime.swift
//  Cathode
//
//  Watch-history reporting for the native AVPlayer path. Uses YouTube's web
//  client authenticated via SAPISIDHASH (cookie-derived), since the TV-client
//  /player endpoint is consistently UNPLAYABLE from non-TV IPs.
//

import Foundation
import OSLog

extension InnerTubeAPI {

    // MARK: - Session
    //
    // Dedicated session for account-bound watchtime calls. Cookie auto-handling
    // is OFF, so the explicit header from `YTCookieAuth`'s isolated snapshot is
    // authoritative and anonymous extraction cannot inherit account state.
    private static let watchtimeSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpShouldSetCookies = false
        config.httpCookieStorage = nil
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config)
    }()
    private static let watchtimeLogger = Logger(
        subsystem: "com.SilverMarcs.SwiftTube",
        category: "WatchtimeAPI"
    )

    // MARK: - CPN

    /// Generates a Client Playback Nonce — 16 chars, random base64url alphabet.
    public static func generateCPN() -> String {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        return String((0..<16).map { _ in alphabet[Int.random(in: 0..<alphabet.count)] })
    }

    // MARK: - Account-bound tracking URLs

    public func fetchAuthenticatedTrackingURLs(videoId: String) async -> PlaybackTrackingURLs? {
        guard let authHeader = await YTCookieAuth.shared.sapisidHashAuthorization() else {
            Self.watchtimeLogger.error("Tracking URL request has no cookie authorization")
            return nil
        }
        do {
            let bootstrap = try await YouTubeStreamExtractor.shared.watchBootstrap(for: videoId)
            var authenticatedWebContext = webClientContext
            var authenticatedWebClient = authenticatedWebContext["client"] as? [String: Any] ?? [:]
            authenticatedWebClient["visitorData"] = bootstrap.visitorData
            authenticatedWebContext["client"] = authenticatedWebClient

            var body = makeBody(client: authenticatedWebContext)
            body["videoId"] = videoId
            body["racyCheckOk"] = true
            body["contentCheckOk"] = true
            body["playbackContext"] = [
                "contentPlaybackContext": [
                    "html5Preference": "HTML5_PREF_WANTS",
                    "signatureTimestamp": bootstrap.signatureTimestamp,
                ]
            ]

            guard let url = URL(string: "https://www.youtube.com/youtubei/v1/player?key=\(apiKey)") else {
                return nil
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
            request.setValue("https://www.youtube.com", forHTTPHeaderField: "Referer")
            request.setValue(InnerTubeClients.Web.nameID, forHTTPHeaderField: "X-YouTube-Client-Name")
            request.setValue(InnerTubeClients.Web.version, forHTTPHeaderField: "X-YouTube-Client-Version")
            request.setValue(bootstrap.visitorData, forHTTPHeaderField: "X-Goog-Visitor-Id")
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
            request.setValue("https://www.youtube.com", forHTTPHeaderField: "X-Origin")
            // Explicit Cookie header from YTCookieAuth's snapshot. Without
            // account cookies YouTube returns no `playbackTracking`, so nothing
            // is recorded.
            if let cookieHeader = await YTCookieAuth.shared.cookieHeader(for: url) {
                request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
            }
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await Self.watchtimeSession.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(statusCode) else {
                Self.watchtimeLogger.error("Tracking URL request returned HTTP \(statusCode)")
                return nil
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                Self.watchtimeLogger.error("Tracking URL response was not a JSON object")
                return nil
            }
            guard let tracking = json["playbackTracking"] as? [String: Any] else {
                Self.watchtimeLogger.error("Player response contained no playbackTracking object")
                return nil
            }
            guard
                let pbStr = (tracking["videostatsPlaybackUrl"] as? [String: Any])?["baseUrl"] as? String,
                let wtStr = (tracking["videostatsWatchtimeUrl"] as? [String: Any])?["baseUrl"] as? String,
                let pbURL = URL(string: pbStr),
                let wtURL = URL(string: wtStr)
            else {
                Self.watchtimeLogger.error("Player response contained incomplete tracking URLs")
                return nil
            }
            let playerConfig = json["playerConfig"] as? [String: Any]
            let vssClientConfig = playerConfig?["vssClientConfig"] as? [String: Any]
            let usesPOST = vssClientConfig?["vssUsePostRequest"] as? Bool ?? false
            let transportName = usesPOST ? "POST" : "GET"
            Self.watchtimeLogger.info(
                "Received watchtime configuration using \(transportName, privacy: .public)"
            )
            return PlaybackTrackingURLs(
                playbackURL: pbURL,
                watchtimeURL: wtURL,
                usesPOST: usesPOST
            )
        } catch {
            Self.watchtimeLogger.error("Tracking URL request failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    // MARK: - Pings

    public func reportPlaybackStarted(
        videoId: String,
        cpn: String,
        trackingURLs: PlaybackTrackingURLs,
        runtime: TimeInterval
    ) async -> Bool {
        let statusCode = await pingTrackingURL(
            trackingURLs.playbackURL,
            usesPOST: trackingURLs.usesPOST,
            extraParams: [
                "ver": "2",
                "cpn": cpn,
                "docid": videoId,
                "cmt": "0",
                "fs": "0",
                "rt": trackingTime(runtime),
                "lact": "0",
                "volume": "100",
                "splay": "1",
            ]
        )
        return (200..<300).contains(statusCode)
    }

    public func reportWatchtime(
        videoId: String,
        cpn: String,
        trackingURLs: PlaybackTrackingURLs,
        segmentStart: TimeInterval,
        segmentEnd: TimeInterval,
        runtime: TimeInterval
    ) async -> Bool {
        let statusCode = await pingTrackingURL(
            trackingURLs.watchtimeURL,
            usesPOST: trackingURLs.usesPOST,
            extraParams: [
                "ver": "2",
                "cpn": cpn,
                "docid": videoId,
                "cmt": trackingTime(segmentEnd),
                "st": trackingTime(segmentStart),
                "et": trackingTime(segmentEnd),
                "fs": "0",
                "rt": trackingTime(runtime),
                "lact": "0",
                "state": "playing",
                "volume": "100",
                "muted": "0",
            ]
        )
        return (200..<300).contains(statusCode)
    }

    private func trackingTime(_ value: TimeInterval) -> String {
        value.formatted(
            .number
                .locale(Locale(identifier: "en_US_POSIX"))
                .grouping(.never)
                .precision(.fractionLength(3))
        )
    }

    // MARK: - Ping transport

    private func pingTrackingURL(
        _ baseURL: URL,
        usesPOST: Bool,
        extraParams: [String: String]
    ) async -> Int {
        var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        var items = comps?.queryItems ?? []
        // YouTube may include default timing values in the base URL. The
        // current playback values must replace them rather than being skipped.
        let replacedNames = Set(extraParams.keys)
        items.removeAll { replacedNames.contains($0.name) }
        for (key, value) in extraParams {
            items.append(URLQueryItem(name: key, value: value))
        }
        comps?.queryItems = items
        guard let url = comps?.url else { return -1 }

        // Fresh SAPISIDHASH per ping — the timestamp must be recent.
        let authHeader = await YTCookieAuth.shared.sapisidHashAuthorization()
        let cookieHeader = await YTCookieAuth.shared.cookieHeader(for: url)

        var request = URLRequest(url: url)
        request.httpMethod = usesPOST ? "POST" : "GET"
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Referer")
        if let authHeader { request.setValue(authHeader, forHTTPHeaderField: "Authorization") }
        if let cookieHeader { request.setValue(cookieHeader, forHTTPHeaderField: "Cookie") }

        do {
            let (_, response) = try await Self.watchtimeSession.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            if !(200..<300).contains(statusCode) {
                Self.watchtimeLogger.error("Tracking ping returned HTTP \(statusCode)")
            }
            return statusCode
        } catch is CancellationError {
            return -2
        } catch {
            Self.watchtimeLogger.error("Tracking ping failed: \(String(describing: error), privacy: .public)")
            return -3
        }
    }
}
