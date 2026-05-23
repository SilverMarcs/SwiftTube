//
//  InnerTubeAPI+Watchtime.swift
//  Cathode
//
//  Watch-history reporting for the native AVPlayer path. Uses YouTube's web
//  client authenticated via SAPISIDHASH (cookie-derived), since the TV-client
//  /player endpoint is consistently UNPLAYABLE from non-TV IPs.
//
//  The iframe playback path does not use this code — its embedded WebView
//  already reports watch progress as part of being a logged-in YouTube
//  session, courtesy of shared cookies in `WKWebsiteDataStore.default()`.
//

import Foundation

extension InnerTubeAPI {

    // MARK: - CPN

    /// Generates a Client Playback Nonce — 16 chars, random base64url alphabet.
    public static func generateCPN() -> String {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        return String((0..<16).map { _ in alphabet[Int.random(in: 0..<alphabet.count)] })
    }

    // MARK: - Account-bound tracking URLs

    public func fetchAuthenticatedTrackingURLs(videoId: String) async -> PlaybackTrackingURLs? {
        guard let authHeader = await YTCookieAuth.shared.sapisidHashAuthorization() else {
            return nil
        }
        do {
            var body = makeBody(client: webClientContext)
            body["videoId"] = videoId
            body["racyCheckOk"] = true
            body["contentCheckOk"] = true

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
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
            request.setValue("https://www.youtube.com", forHTTPHeaderField: "X-Origin")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await session.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(statusCode) else { return nil }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            guard let tracking = json["playbackTracking"] as? [String: Any] else { return nil }
            guard
                let pbStr = (tracking["videostatsPlaybackUrl"] as? [String: Any])?["baseUrl"] as? String,
                let wtStr = (tracking["videostatsWatchtimeUrl"] as? [String: Any])?["baseUrl"] as? String,
                let pbURL = URL(string: pbStr),
                let wtURL = URL(string: wtStr)
            else { return nil }
            return PlaybackTrackingURLs(playbackURL: pbURL, watchtimeURL: wtURL)
        } catch {
            return nil
        }
    }

    // MARK: - Pings

    public func reportPlaybackStarted(videoId: String, cpn: String, trackingURLs: PlaybackTrackingURLs) async {
        _ = await pingTrackingURL(trackingURLs.playbackURL, extraParams: [
            "ver":   "2",
            "cpn":   cpn,
            "docid": videoId,
            "cmt":   "0",
        ])
    }

    public func reportWatchtime(
        videoId: String,
        cpn: String,
        trackingURLs: PlaybackTrackingURLs,
        segmentStart: TimeInterval,
        segmentEnd: TimeInterval
    ) async {
        _ = await pingTrackingURL(trackingURLs.watchtimeURL, extraParams: [
            "ver":   "2",
            "cpn":   cpn,
            "docid": videoId,
            "cmt":   String(format: "%.3f", segmentEnd),
            "st":    String(format: "%.3f", segmentStart),
            "et":    String(format: "%.3f", segmentEnd),
        ])
    }

    // MARK: - Ping transport

    private func pingTrackingURL(_ baseURL: URL, extraParams: [String: String]) async -> Int {
        var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        var items = comps?.queryItems ?? []
        for (key, value) in extraParams where !items.contains(where: { $0.name == key }) {
            items.append(URLQueryItem(name: key, value: value))
        }
        comps?.queryItems = items
        guard let url = comps?.url else { return -1 }

        // Fresh SAPISIDHASH per ping — the timestamp must be recent.
        let authHeader = await YTCookieAuth.shared.sapisidHashAuthorization()
        let cookieHeader = await YTCookieAuth.shared.cookieHeader(for: url)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Referer")
        if let authHeader { request.setValue(authHeader, forHTTPHeaderField: "Authorization") }
        if let cookieHeader { request.setValue(cookieHeader, forHTTPHeaderField: "Cookie") }

        do {
            let (_, response) = try await session.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode ?? -1
        } catch is CancellationError {
            return -2
        } catch {
            return -3
        }
    }
}
