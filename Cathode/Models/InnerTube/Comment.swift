import Foundation

/// A YouTube comment and the reply thread belonging to it.
public nonisolated struct Comment: Sendable, Identifiable {
    public let id: String
    public let author: String
    public let authorAvatarURL: URL?
    public let text: String
    public let likeCount: String
    public let publishedTime: String
    public let isLiked: Bool
    public let replies: [Comment]
    public let replyContinuationToken: String?

    public init(
        id: String,
        author: String,
        authorAvatarURL: URL?,
        text: String,
        likeCount: String,
        publishedTime: String,
        isLiked: Bool,
        replies: [Comment] = [],
        replyContinuationToken: String? = nil
    ) {
        self.id = id
        self.author = author
        self.authorAvatarURL = authorAvatarURL
        self.text = text
        self.likeCount = likeCount
        self.publishedTime = publishedTime
        self.isLiked = isLiked
        self.replies = replies
        self.replyContinuationToken = replyContinuationToken
    }
}
