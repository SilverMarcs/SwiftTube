import Foundation

/// Cookie-free transports for YouTube player resolution and signed media.
enum YouTubeMediaTransport {
    /// Player metadata and short-lived extraction requests may share a pool.
    nonisolated static let session = makeSession(resourceTimeout: 45)

    /// Media gets a playback-scoped pool. Reusing one process-wide pool here
    /// allowed a stale googlevideo connection to poison later range requests
    /// until the whole app was relaunched.
    nonisolated static func makePlaybackSession() -> URLSession {
        makeSession(resourceTimeout: 120, maximumConnectionsPerHost: 6)
    }

    private nonisolated static func makeSession(
        resourceTimeout: TimeInterval,
        maximumConnectionsPerHost: Int? = nil
    ) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = resourceTimeout
        configuration.waitsForConnectivity = true
        if let maximumConnectionsPerHost {
            configuration.httpMaximumConnectionsPerHost = maximumConnectionsPerHost
        }
        return URLSession(configuration: configuration)
    }
}
