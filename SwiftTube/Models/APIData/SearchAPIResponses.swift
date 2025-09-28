// SearchAPIResponses.swift
import Foundation

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