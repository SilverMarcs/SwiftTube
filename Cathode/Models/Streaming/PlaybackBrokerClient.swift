import Foundation

actor PlaybackBrokerClient {
    static let shared = PlaybackBrokerClient()

    // Token-only endpoint. API credentials come from the shared iCloud settings.
    nonisolated static let baseURLString = "https://c-ce88eb37d90d7509.lynksphere.com"

    private struct RequestBody: Encodable {
        let videoID: String
        let refresh: Bool

        enum CodingKeys: String, CodingKey {
            case videoID = "video_id"
            case refresh
        }
    }

    private struct ResponseBody: Decodable {
        let videoID: String
        let token: String
        let expiresAt: String
        let client: String
        let context: String
        enum CodingKeys: String, CodingKey {
            case videoID = "video_id"
            case token = "po_token"
            case expiresAt = "expires_at"
            case client, context
        }
    }

    private var cachedTokens: [String: PlaybackPOToken] = [:]

    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 60
        session = URLSession(configuration: configuration)
    }

    func token(videoID: String, refresh: Bool) async throws -> PlaybackPOToken {
        try Task.checkCancellation()
        let configured = await MainActor.run {
            let settings = ExperimentalPlaybackSettings.shared
            return (settings.serverURL, settings.apiKey)
        }
        let baseURL = URL(string: configured.0)
        let apiKey = configured.1
        guard let baseURL, Self.isAllowedServerURL(baseURL), !apiKey.isEmpty,
              let host = baseURL.host(),
              host != "invalid", !host.hasSuffix(".invalid") else {
            throw PlaybackBrokerError.notConfigured
        }
        guard videoID.utf8.count == 11,
              videoID.utf8.allSatisfy({ byte in
                  (65...90).contains(byte) || (97...122).contains(byte)
                      || (48...57).contains(byte) || byte == 45 || byte == 95
              }) else {
            throw PlaybackBrokerError.invalidVideoID
        }

        let cacheKey = baseURL.absoluteString + "|" + apiKey + "|" + videoID
        if !refresh, let token = cachedTokens[cacheKey], token.expiresAt > Date().addingTimeInterval(60) {
            return token
        }
        cachedTokens = cachedTokens.filter { $0.value.expiresAt > Date().addingTimeInterval(60) }
        if cachedTokens.count > 64 { cachedTokens.removeAll() }
        var request = URLRequest(url: baseURL.appending(path: "v1/token"))
        request.httpMethod = "POST"
        request.httpShouldHandleCookies = false
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer " + apiKey, forHTTPHeaderField: "Authorization")
        // The service only generates a token; it never resolves or downloads media.
        request.timeoutInterval = 60
        request.httpBody = try JSONEncoder().encode(RequestBody(videoID: videoID, refresh: refresh))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw PlaybackBrokerError.unavailable
        }
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse else {
            throw PlaybackBrokerError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            // Do not display raw provider diagnostics or token material.
            throw PlaybackBrokerError.rejected(statusCode: response.statusCode)
        }
        guard let result = try? JSONDecoder().decode(ResponseBody.self, from: data),
              result.videoID == videoID, result.client == "mweb", result.context == "gvs",
              !result.token.isEmpty, result.token.utf8.count <= 16384,
              let expiresAt = Self.parseDate(result.expiresAt), expiresAt > Date().addingTimeInterval(60)
        else { throw PlaybackBrokerError.invalidResponse }
        let token = PlaybackPOToken(videoID: videoID, value: result.token,
                                    expiresAt: min(expiresAt, Date().addingTimeInterval(3600)))
        cachedTokens[cacheKey] = token
        return token
    }

    nonisolated private static func parseDate(_ text: String) -> Date? {
        (try? Date(text, strategy: .iso8601.year().month().day().time(includingFractionalSeconds: true).timeZone(separator: .colon)))
            ?? (try? Date(text, strategy: .iso8601))
    }

    nonisolated static func isAllowedServerURL(_ url: URL) -> Bool {
        guard isWebURL(url), url.query == nil, url.fragment == nil else { return false }
        guard url.scheme == "http" else { return true }
        let host = url.host() ?? ""
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        let octets = parts.compactMap { UInt8($0) }
        let privateIPv4 = parts.count == 4 && octets.count == 4 && (octets[0] == 10
            || (octets[0] == 192 && octets[1] == 168)
            || (octets[0] == 172 && (16...31).contains(octets[1])))
        // HTTP is limited to local-network development; remote credentials use TLS.
        return host == "localhost" || host == "127.0.0.1" || host == "::1"
            || host.hasSuffix(".local") || privateIPv4
    }

    nonisolated private static func isWebURL(_ url: URL) -> Bool {
        (url.scheme == "https" || url.scheme == "http")
            && url.host()?.isEmpty == false && url.user() == nil && url.password() == nil
    }
}
