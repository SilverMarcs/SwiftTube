import Foundation

// MARK: - LikeStatus

/// The user's current like state for a video.
public enum LikeStatus: Sendable, Codable {
    case like
    case dislike
    case none
}

// MARK: - NextInfo

/// Combined result from the `/next` InnerTube endpoint.
public struct NextInfo: Sendable, Codable {
    public let relatedVideos: [Video]
    public let likeStatus: LikeStatus
    public let chapters: [Chapter]
}

// MARK: - Comment

/// A single top-level YouTube comment returned by the `/next` continuation endpoint.
public struct Comment: Sendable, Identifiable {
    public let id: String
    public let author: String
    public let authorAvatarURL: URL?
    public let text: String
    public let likeCount: String
    public let publishedTime: String
    public let isLiked: Bool
}

// MARK: - PlayerInfo

/// Account-bound watchtime tracking URLs returned by an authenticated /player
/// request. Pinging them records the view in YouTube's official watch history.
public struct PlaybackTrackingURLs: Sendable {
    /// Fire once when playback begins.
    public let playbackURL: URL
    /// Fire periodically during playback (~every 5s) and on stop.
    public let watchtimeURL: URL
}

/// Video metadata returned by the InnerTube `/player` endpoint. Stream URLs are
/// no longer carried here — playback resolves on-device via YouTubeKit.
public struct PlayerInfo: Sendable {
    public let video: Video
}

// MARK: - ITAPIError

public enum ITAPIError: LocalizedError {
    case httpError(Int)
    case decodingError(String)
    case notAuthenticated
    case unavailable(String)
    case invalidURL(String)
    /// Thrown when YouTube's `/player` response indicates the request was blocked due to
    /// the source IP address (VPN, proxy, shared datacenter IP). The associated value is
    /// the raw `playabilityStatus.reason` string from the response.
    case ipBlocked(String)

    public var errorDescription: String? {
        switch self {
        case .httpError(let code):      return "HTTP error \(code)"
        case .decodingError(let msg):   return "Decoding error: \(msg)"
        case .notAuthenticated:          return "You are not signed in"
        case .unavailable(let reason):   return reason
        case .invalidURL(let endpoint):  return "Could not build URL for endpoint: \(endpoint)"
        case .ipBlocked:
            return "YouTube is temporarily blocking this network. Disable your VPN, try a different VPN server, or wait a few minutes and retry."
        }
    }
}

// MARK: - Safe array subscript

extension Array {
    nonisolated subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
