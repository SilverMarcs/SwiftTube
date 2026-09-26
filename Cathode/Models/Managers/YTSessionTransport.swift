import Foundation

/// Each request uses a private cookie jar seeded from an immutable snapshot.
/// Explicitly applies Set-Cookie, expiry/deletion and redirects to that jar;
/// the caller decides whether its final contents still belong to the active login.
nonisolated enum YTSessionTransport {
    struct Response: Sendable {
        var sessionID: UUID? = nil
        let data: Data
        let http: HTTPURLResponse
        let cookies: [YTStoredCookie]
    }

    static func send(_ request: URLRequest, cookies: [YTStoredCookie],
                     configuration: URLSessionConfiguration = .ephemeral) async throws -> Response {
        configuration.httpCookieAcceptPolicy = .always
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        guard let jar = configuration.httpCookieStorage else { throw URLError(.unknown) }
        for cookie in cookies where cookie.isValid(at: Date()) {
            if let value = cookie.httpCookie { jar.setCookie(value) }
        }
        let session = URLSession(configuration: configuration, delegate: YTSessionRedirectDelegate(jar: jar), delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        var request = request
        request.httpShouldHandleCookies = false
        request.setValue(cookieHeader(in: jar, for: request.url), forHTTPHeaderField: "Cookie")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        receiveCookies(from: http, into: jar)
        return Response(data: data, http: http, cookies: YTCookieSession.normalized(jar.cookies ?? []))
    }

    static func cookieHeader(in jar: HTTPCookieStorage, for url: URL?) -> String? {
        guard let url else { return nil }
        let cookies = (jar.cookies(for: url) ?? []).filter { YTStoredCookie($0).matches(url) }
        return cookies.isEmpty ? nil : HTTPCookie.requestHeaderFields(with: cookies)["Cookie"]
    }

    static func receiveCookies(from response: HTTPURLResponse, into jar: HTTPCookieStorage) {
        guard let url = response.url, let host = url.host,
              YTStoredCookie.isYouTubeDomain(host) else { return }
        let headers = response.allHeaderFields.reduce(into: [String: String]()) { result, entry in
            if let name = entry.key as? String, let value = entry.value as? String { result[name] = value }
        }
        for cookie in HTTPCookie.cookies(withResponseHeaderFields: headers, for: url) {
            let domain = cookie.domain.trimmingCharacters(in: CharacterSet(charactersIn: "."))
            guard YTStoredCookie.isYouTubeDomain(domain), host == domain || host.hasSuffix("." + domain) else { continue }
            // deleteCookie(responseCookie) can fail when the existing cookie is
            // HttpOnly and the deletion response omits that flag. Delete the
            // stored object by RFC identity (name/domain/path) before replacing.
            for existing in jar.cookies ?? [] where YTStoredCookie(existing).identity == YTStoredCookie(cookie).identity {
                jar.deleteCookie(existing)
            }
            if cookie.expiresDate.map({ $0 <= Date() }) != true {
                jar.setCookie(cookie)
            }
        }
    }
}
