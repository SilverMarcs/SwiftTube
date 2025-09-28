// APIResponses.swift
import Foundation

// MARK: - API Response Models
struct ChannelResponse: Codable {
    let items: [ChannelItem]
}

struct ChannelItem: Codable {
    let id: String
    let snippet: ChannelSnippet
    let contentDetails: ChannelContentDetails
    let statistics: ChannelStatistics
}

struct ChannelSnippet: Codable {
    let title: String
    let description: String
    let thumbnails: Thumbnails
}

struct ChannelContentDetails: Codable {
    let relatedPlaylists: RelatedPlaylists
}

struct RelatedPlaylists: Codable {
    let uploads: String
}

struct ChannelStatistics: Codable {
    let viewCount: String
    let subscriberCount: String
}

struct PlaylistResponse: Codable {
    let items: [PlaylistItem]
}

struct PlaylistItem: Codable {
    let snippet: VideoSnippet
    let contentDetails: VideoContentDetails
}

struct VideoSnippet: Codable {
    let title: String
    let description: String
    let thumbnails: Thumbnails
    let channelTitle: String
}

struct VideoContentDetails: Codable {
    let videoId: String
    let videoPublishedAt: String
}

struct Thumbnails: Codable {
    let medium: Thumbnail
    let high: Thumbnail?
}

struct Thumbnail: Codable {
    let url: String
}

struct SearchResponse: Codable {
    let items: [SearchItem]
}

struct SearchItem: Codable {
    let id: SearchId
    let snippet: SearchSnippet
}

struct SearchId: Codable {
    let channelId: String
}

struct SearchSnippet: Codable {
    let title: String
    let description: String
    let thumbnails: Thumbnails
}

// MARK: - Video Detail Models
// API Response Models
// TODO: is this needed?
struct VideoDetail {
    let id: String
    let title: String
    let description: String
    let channelId: String
    let channelTitle: String
    let publishedAt: Date
    let thumbnailURL: String
    let duration: String
    let viewCount: String
    let likeCount: String?
    let commentCount: String?
    let tags: [String]
    let categoryId: String
    let definition: String
    let caption: Bool
    let privacyStatus: String
    let embeddable: Bool
}

struct VideoDetailResponse: Codable {
    let items: [VideoDetailItem]
}

struct VideoDetailItem: Codable {
    let id: String
    let snippet: VideoDetailSnippet
    let contentDetails: VideoDetailContentDetails
    let statistics: VideoStatistics
}

struct VideoDetailSnippet: Codable {
    let title: String
    let description: String
    let channelId: String
    let channelTitle: String
    let publishedAt: String
    let thumbnails: Thumbnails
    let tags: [String]?
}

struct VideoDetailContentDetails: Codable {
    let duration: String
    let definition: String
    let caption: String
}

struct VideoStatistics: Codable {
    let viewCount: String
    let likeCount: String?
    let commentCount: String?
}

// MARK: - Comment Models
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

// MARK: - Error Response
struct YouTubeErrorResponse: Codable {
    let error: YouTubeError
}

struct YouTubeError: Codable {
    let code: Int
    let message: String
    let errors: [YouTubeErrorDetail]
}

struct YouTubeErrorDetail: Codable {
    let domain: String
    let reason: String
    let message: String
}
