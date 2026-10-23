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

// MARK: - ITAPIError

public enum ITAPIError: LocalizedError {
    case httpError(Int)
    case decodingError(String)
    case notAuthenticated
    case invalidURL(String)

    public var errorDescription: String? {
        switch self {
        case .httpError(let code):      return "HTTP error \(code)"
        case .decodingError(let msg):   return "Decoding error: \(msg)"
        case .notAuthenticated:          return "You are not signed in"
        case .invalidURL(let endpoint):  return "Could not build URL for endpoint: \(endpoint)"
        }
    }
}

// MARK: - Safe array subscript

extension Array {
    nonisolated subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
