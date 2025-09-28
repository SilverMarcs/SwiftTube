// Comment.swift
import Foundation
import SwiftData

@Model
final class Comment {
    @Attribute(.unique) var id: String
    var authorDisplayName: String
    var authorProfileImageUrl: String?
    var authorChannelUrl: String?
    var authorChannelId: String?
    var textDisplay: String      // HTML formatted text
    var textOriginal: String     // Plain text
    var likeCount: Int
    var publishedAt: Date
    var updatedAt: Date?
    var totalReplyCount: Int
    var isTopLevel: Bool         // true for top-level comments, false for replies
    var parentCommentId: String? // nil for top-level, contains parent ID for replies
    
    @Relationship var video: Video?
    @Relationship(inverse: \Comment.parentComment) var replies: [Comment] = []
    @Relationship var parentComment: Comment?
    
    init(
        id: String,
        authorDisplayName: String,
        authorProfileImageUrl: String? = nil,
        authorChannelUrl: String? = nil,
        authorChannelId: String? = nil,
        textDisplay: String,
        textOriginal: String,
        likeCount: Int,
        publishedAt: Date,
        updatedAt: Date? = nil,
        totalReplyCount: Int = 0,
        isTopLevel: Bool = true,
        parentCommentId: String? = nil,
        video: Video? = nil
    ) {
        self.id = id
        self.authorDisplayName = authorDisplayName
        self.authorProfileImageUrl = authorProfileImageUrl
        self.authorChannelUrl = authorChannelUrl
        self.authorChannelId = authorChannelId
        self.textDisplay = textDisplay
        self.textOriginal = textOriginal
        self.likeCount = likeCount
        self.publishedAt = publishedAt
        self.updatedAt = updatedAt
        self.totalReplyCount = totalReplyCount
        self.isTopLevel = isTopLevel
        self.parentCommentId = parentCommentId
        self.video = video
    }
}