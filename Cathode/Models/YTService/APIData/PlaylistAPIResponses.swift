import Foundation

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
