// CommentAPIResponses.swift
import Foundation

struct CommentThreadsResponse: Codable {
    let items: [CommentThread]
    let nextPageToken: String?
}

struct CommentThread: Codable {
    let id: String
    let snippet: CommentThreadSnippet
    let replies: CommentReplies?
}

struct CommentThreadSnippet: Codable {
    let videoId: String
    let channelId: String
    let topLevelComment: CommentItem
    let totalReplyCount: Int
}

struct CommentReplies: Codable {
    let comments: [CommentItem]
}

struct CommentItem: Codable {
    let id: String
    let snippet: CommentSnippet
}

struct CommentSnippet: Codable {
    let authorDisplayName: String
    let authorProfileImageUrl: String?
    let textDisplay: String
    let textOriginal: String
    let likeCount: Int
    let publishedAt: String
    let updatedAt: String?
}