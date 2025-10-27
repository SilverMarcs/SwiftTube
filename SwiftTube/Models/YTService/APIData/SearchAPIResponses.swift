import Foundation

struct SearchResponse: Codable {
    let items: [SearchItem]
}

struct SearchItem: Codable {
    let kind: String
    let id: SearchId
    let snippet: SearchSnippet
}

struct SearchId: Codable {
    let kind: String
    let videoId: String?
    let channelId: String?
}

struct SearchSnippet: Codable {
    let title: String
    let description: String
    let thumbnails: Thumbnails
    let channelId: String
    let channelTitle: String
}