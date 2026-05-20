import Foundation
import os
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private let tubeLog = Logger(subsystem: appSubsystem, category: "InnerTube")

// MARK: - Networking

extension InnerTubeAPI {

    // MARK: - Body builders

    func makeBody(client: [String: Any], continuationToken: String? = nil, includeVisitorData: Bool = false, includePoToken: Bool = false) -> [String: Any] {
        var body: [String: Any] = ["context": client]
        if let token = continuationToken {
            body["continuation"] = token
        }
        if includeVisitorData, let visitor = visitorData {
            body["visitorData"] = visitor
        }
        if includePoToken, let pot = poToken {
            body["serviceIntegrityDimensions"] = ["poToken": pot]
        }
        return body
    }

    // MARK: - Transport

    /// Player requests use the iOS client UA, googleapis.com base, and no auth header.
    func postPlayer(body: [String: Any]) async throws -> [String: Any] {
        guard var comps = URLComponents(url: playerBaseURL.appendingPathComponent("player"), resolvingAgainstBaseURL: false) else {
            throw ITAPIError.invalidURL("player")
        }
        comps.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = comps.url else { throw ITAPIError.invalidURL("player") }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(iosUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(InnerTubeClients.iOS.nameID, forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue(InnerTubeClients.iOS.version, forHTTPHeaderField: "X-YouTube-Client-Version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let playerVideoId = body["videoId"] as? String ?? ""
        tubeLog.notice("POST /player (iOS) videoId=\(playerVideoId, privacy: .public)")
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            tubeLog.error("❌ HTTP \(statusCode, privacy: .public) for /player")
            throw ITAPIError.httpError(statusCode)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            tubeLog.error("❌ Non-dictionary JSON root for /player")
            throw ITAPIError.decodingError("Root JSON is not a dictionary")
        }
        if let error = json["error"] as? [String: Any] {
            tubeLog.error("❌ API error in /player: \(String(describing: error["message"] ?? error), privacy: .public)")
        } else {
            let topKeys = Array(json.keys.prefix(6))
            tubeLog.notice("✅ /player HTTP \(statusCode, privacy: .public) keys: \(topKeys, privacy: .public)")
        }
        return json
    }

    /// Android client player request — used for download URL resolution.
    /// Android client headers use googleapis.com like iOS, but with Android UA/client IDs.
    func postAndroid(endpoint: String, body: [String: Any]) async throws -> [String: Any] {
        guard var comps = URLComponents(url: playerBaseURL.appendingPathComponent(endpoint), resolvingAgainstBaseURL: false) else {
            throw ITAPIError.invalidURL(endpoint)
        }
        comps.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = comps.url else { throw ITAPIError.invalidURL(endpoint) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(InnerTubeClients.Android.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(InnerTubeClients.Android.nameID, forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue(InnerTubeClients.Android.version, forHTTPHeaderField: "X-YouTube-Client-Version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let videoId = body["videoId"] as? String ?? ""
        tubeLog.notice("POST /\(endpoint, privacy: .public) [Android] videoId=\(videoId, privacy: .public)")
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            tubeLog.error("❌ HTTP \(statusCode, privacy: .public) for /\(endpoint, privacy: .public) [Android]")
            throw ITAPIError.httpError(statusCode)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            tubeLog.error("❌ Non-dictionary JSON root for /\(endpoint, privacy: .public) [Android]")
            throw ITAPIError.decodingError("Root JSON is not a dictionary")
        }
        if let error = json["error"] as? [String: Any] {
            tubeLog.error("❌ API error in /\(endpoint, privacy: .public) [Android]: \(String(describing: error["message"] ?? error), privacy: .public)")
        } else {
            let topKeys = Array(json.keys.prefix(6))
            tubeLog.notice("✅ /\(endpoint, privacy: .public) [Android] HTTP \(statusCode, privacy: .public) keys: \(topKeys, privacy: .public)")
        }
        return json
    }

    func post(endpoint: String, body: [String: Any], useAuth: Bool = false) async throws -> [String: Any] {
        guard var comps = URLComponents(url: baseURL.appendingPathComponent(endpoint), resolvingAgainstBaseURL: false) else {
            throw ITAPIError.invalidURL(endpoint)
        }
        let resolvedToken = useAuth ? authToken : nil
        if resolvedToken == nil {
            comps.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        }
        guard let url = comps.url else { throw ITAPIError.invalidURL(endpoint) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue(InnerTubeClients.Web.nameID, forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue(InnerTubeClients.Web.version, forHTTPHeaderField: "X-YouTube-Client-Version")
        if let token = resolvedToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let authLabel = resolvedToken != nil ? "yes" : "no"
        tubeLog.notice("POST /\(endpoint, privacy: .public) [WEB] auth=\(authLabel, privacy: .public)")
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            tubeLog.error("❌ HTTP \(statusCode, privacy: .public) for /\(endpoint, privacy: .public)")
            throw ITAPIError.httpError(statusCode)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            tubeLog.error("❌ Non-dictionary JSON root for /\(endpoint, privacy: .public)")
            throw ITAPIError.decodingError("Root JSON is not a dictionary")
        }
        let topKeys = Array(json.keys.prefix(6))
        if let error = json["error"] as? [String: Any] {
            tubeLog.error("❌ API error in /\(endpoint, privacy: .public): \(String(describing: error["message"] ?? error), privacy: .public)")
        } else {
            tubeLog.notice("✅ /\(endpoint, privacy: .public) HTTP \(statusCode, privacy: .public) keys: \(topKeys, privacy: .public)")
        }
        return json
    }

    /// Unauthenticated TVHTML5 browse on www.youtube.com.
    /// FE* category browse IDs (FEgaming, FEshorts, FEmusic, …) require the TVHTML5
    /// client format but return 400 on youtubei.googleapis.com without a valid auth token.
    /// Posting to www.youtube.com with TV client headers resolves this.
    func postTVCategory(endpoint: String, body: [String: Any]) async throws -> [String: Any] {
        guard var comps = URLComponents(url: baseURL.appendingPathComponent(endpoint),
                                        resolvingAgainstBaseURL: false) else {
            throw ITAPIError.invalidURL(endpoint)
        }
        comps.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = comps.url else { throw ITAPIError.invalidURL(endpoint) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue(InnerTubeClients.TV.nameID, forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue(InnerTubeClients.TV.version, forHTTPHeaderField: "X-YouTube-Client-Version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        tubeLog.notice("POST /\(endpoint, privacy: .public) [TV-category]")
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            tubeLog.error("❌ HTTP \(statusCode, privacy: .public) for /\(endpoint, privacy: .public) [TV-category]")
            throw ITAPIError.httpError(statusCode)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            tubeLog.error("❌ Non-dictionary JSON root for /\(endpoint, privacy: .public) [TV-category]")
            throw ITAPIError.decodingError("Root JSON is not a dictionary")
        }
        if let error = json["error"] as? [String: Any] {
            tubeLog.error("❌ API error in /\(endpoint, privacy: .public) [TV-category]: \(String(describing: error["message"] ?? error), privacy: .public)")
        } else {
            let topKeys = Array(json.keys.prefix(6))
            tubeLog.notice("✅ /\(endpoint, privacy: .public) [TV-category] HTTP \(statusCode, privacy: .public) keys: \(topKeys, privacy: .public)")
        }
        return json
    }

    /// Authenticated InnerTube endpoint — TVHTML5 client on youtubei.googleapis.com.
    /// Required for subscriptions, history, playlists, and personalised home: the OAuth
    /// token issued by the TV device-code flow is matched to this client. The WEB client
    /// on www.youtube.com rejects Bearer tokens (returns 400).
    ///
    /// Android alignment: when Bearer token is present, no ?key= param is sent
    /// (mirrors RetrofitOkHttpHelper — authHeaders non-empty → skip key, apply Bearer headers).
    /// When unauthenticated, the WEB key is used as on all other clients.
    func postTV(
        endpoint: String,
        body: [String: Any],
        useAuth: Bool = true,
        explicitBearerToken: String? = nil
    ) async throws -> [String: Any] {
        guard var comps = URLComponents(url: playerBaseURL.appendingPathComponent(endpoint),
                                        resolvingAgainstBaseURL: false) else {
            throw ITAPIError.invalidURL(endpoint)
        }
        // Android: no ?key= when Bearer present; WEB key for unauthenticated.
        // `explicitBearerToken` lets callers bypass actor-state and supply a token directly.
        let resolvedToken = explicitBearerToken ?? (useAuth ? authToken : nil)
        let shouldAuthenticate = resolvedToken != nil
        if !shouldAuthenticate {
            comps.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        }
        guard let url = comps.url else { throw ITAPIError.invalidURL(endpoint) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(InnerTubeClients.TV.nameID, forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue(InnerTubeClients.TV.version, forHTTPHeaderField: "X-YouTube-Client-Version")
        if let token = resolvedToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let authLabel = shouldAuthenticate ? "yes" : "no"
        tubeLog.notice("POST /\(endpoint, privacy: .public) [TV] auth=\(authLabel, privacy: .public)")
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            tubeLog.error("❌ HTTP \(statusCode, privacy: .public) for /\(endpoint, privacy: .public) [TV]")
            throw ITAPIError.httpError(statusCode)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            tubeLog.error("❌ Non-dictionary JSON root for /\(endpoint, privacy: .public) [TV]")
            throw ITAPIError.decodingError("Root JSON is not a dictionary")
        }
        if let error = json["error"] as? [String: Any] {
            tubeLog.error("❌ API error in /\(endpoint, privacy: .public) [TV]: \(String(describing: error["message"] ?? error), privacy: .public)")
        } else {
            let topKeys = Array(json.keys.prefix(6))
            tubeLog.notice("✅ /\(endpoint, privacy: .public) [TV] HTTP \(statusCode, privacy: .public) keys: \(topKeys, privacy: .public)")
        }
        return json
    }
}
