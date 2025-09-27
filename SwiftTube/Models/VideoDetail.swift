// VideoDetail.swift
import Foundation

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