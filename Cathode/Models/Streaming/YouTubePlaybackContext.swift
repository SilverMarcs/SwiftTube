import Foundation

/// Pins credentials and the client policy for one extraction. OAuth used by
/// account browsing does not authenticate these browser-based player clients.
nonisolated struct YouTubePlaybackContext: Sendable {
    static let anonymous = YouTubePlaybackContext(strategy: .visionOS)

    let strategy: PlaybackStrategy
    let authorization: String?
    let cookies: String?

    init(strategy: PlaybackStrategy, authorization: String? = nil, cookies: String? = nil) {
        self.strategy = strategy
        self.authorization = strategy == .authenticatedEmbedded ? authorization : nil
        self.cookies = strategy == .authenticatedEmbedded ? cookies : nil
    }
}
