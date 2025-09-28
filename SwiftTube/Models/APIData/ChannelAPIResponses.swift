// ChannelAPIResponses.swift
import Foundation

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