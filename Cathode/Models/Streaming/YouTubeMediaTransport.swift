import Foundation

/// A single cookie-free transport for YouTube player resolution and every
/// request made against the signed media URLs it returns.
///
/// All stages intentionally share one connection pool and identical cookie,
/// cache, timeout, and connectivity behavior.
enum YouTubeMediaTransport {
    nonisolated static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 45
        configuration.waitsForConnectivity = true
        return URLSession(configuration: configuration)
    }()
}
