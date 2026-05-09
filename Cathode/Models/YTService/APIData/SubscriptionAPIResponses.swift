// SubscriptionAPIResponses.swift
import Foundation

struct SubscriptionListResponse: Codable {
    let kind: String
    let nextPageToken: String?
    let prevPageToken: String?
    let pageInfo: PageInfo
    let items: [SubscriptionItem]
}

struct PageInfo: Codable {
    let totalResults: Int
    let resultsPerPage: Int
}

struct SubscriptionItem: Codable {
    let kind: String
    let id: String
    let snippet: SubscriptionSnippet
}

struct SubscriptionSnippet: Codable {
    let publishedAt: String
    let title: String
    let description: String
    let resourceId: SubscriptionResourceId
    let channelId: String
    let thumbnails: Thumbnails
}

struct SubscriptionResourceId: Codable {
    let kind: String
    let channelId: String
}
