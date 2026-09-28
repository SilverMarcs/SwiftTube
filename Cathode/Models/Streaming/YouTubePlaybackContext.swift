import Foundation

/// Pins credentials and the client policy for one extraction. OAuth used by
/// account browsing does not authenticate these browser-based player clients.
nonisolated struct YouTubePlaybackContext: Sendable {
    enum Strategy: Sendable {
        case visionOS
        case anonymousMWEB
        case authenticatedEmbedded
    }

    static let local = YouTubePlaybackContext(usingTokenService: false)

    let strategy: Strategy
    let authorization: String?
    let cookies: String?

    var requiresPOToken: Bool { strategy == .anonymousMWEB }

    init(usingTokenService: Bool, authorization: String? = nil, cookies: String? = nil) {
        guard usingTokenService else {
            strategy = .visionOS
            self.authorization = nil
            self.cookies = nil
            return
        }
        if let authorization, !authorization.isEmpty, let cookies, !cookies.isEmpty {
            strategy = .authenticatedEmbedded
            self.authorization = authorization
            self.cookies = cookies
        } else {
            strategy = .anonymousMWEB
            self.authorization = nil
            self.cookies = nil
        }
    }
}
