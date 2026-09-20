//
//  InnerTubeAPI+Watchtime.swift
//  Cathode
//
//  Watch-history reporting for the native AVPlayer path. Uses YouTube's web
//  watch page authenticated with the isolated cookie snapshot. Tracking is
//  independent of the client or PO token used to obtain the media stream.
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
        guard var components = URLComponents(string: "https://www.youtube.com/watch") else { return nil }
        components.queryItems = [
            URLQueryItem(name: "v", value: videoId),
            URLQueryItem(name: "hl", value: "en"),
        ]
        guard let url = components.url,
              let cookies = await YTCookieAuth.shared.cookieHeader(for: url) else {
            await YTCookieAuth.shared.setHistorySyncStatus(.needsSignIn)
            return nil
        }
        do {
            // Fetch account-bound tracking independently of media extraction.
            // Both normal and PO-token streams use this same reporting path.
            // A separate WEB /player POST can return loggedOut=true despite
            // valid cookies, whereas the authenticated watch page retains them.
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            request.httpShouldHandleCookies = false
            request.setValue(cookies, forHTTPHeaderField: "Cookie")
            request.setValue(InnerTubeClients.WebSafari.userAgent, forHTTPHeaderField: "User-Agent")
            request.setValue("https://www.youtube.com", forHTTPHeaderField: "Referer")
            let (data, response) = try await Self.watchtimeSession.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(status), let html = String(data: data, encoding: .utf8) else {
                Self.watchtimeLogger.error("Authenticated watch page returned HTTP \(status)")
                await YTCookieAuth.shared.setHistorySyncStatus(.unavailable)
                return nil
            }
            let tracking = try WatchPageTrackingParser.parse(html, videoID: videoId)
            await YTCookieAuth.shared.setHistorySyncStatus(.authenticated)
            Self.watchtimeLogger.info("Received authenticated watch-page tracking configuration")
            return tracking
        } catch is CancellationError {
            return nil
        } catch WatchPageTrackingParser.Failure.unauthenticated {
            await YTCookieAuth.shared.setHistorySyncStatus(.needsSignIn)
            Self.watchtimeLogger.error("Watch page is signed out; refusing anonymous tracking URLs")
            return nil
        } catch {
            if Task.isCancelled { return nil }
            await YTCookieAuth.shared.setHistorySyncStatus(.unavailable)
            // Do not log response bodies or signed tracking URLs.
            Self.watchtimeLogger.error("Could not read authenticated watch-page tracking configuration")
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
        guard let authHeader = await YTCookieAuth.shared.sapisidHashAuthorization(),
              let cookieHeader = await YTCookieAuth.shared.cookieHeader(for: url) else {
            await YTCookieAuth.shared.setHistorySyncStatus(.needsSignIn)
            return -1
        }

        var request = URLRequest(url: url)
        request.httpMethod = usesPOST ? "POST" : "GET"
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Referer")
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        request.setValue(InnerTubeClients.WebSafari.userAgent, forHTTPHeaderField: "User-Agent")

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
