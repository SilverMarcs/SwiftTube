// VideoDetailAPIResponses.swift
import Foundation

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