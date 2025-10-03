//
//  RSSModels.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 28/09/2025.
//

import Foundation

// MARK: - RSS Feed Models
struct Feed {
    let title: String
    let entries: [Entry]
}

struct Entry: Identifiable {
    let id = UUID()
    let title: String
    let link: String
    let published: Date
    let updated: Date
    let author: Author
    let mediaGroup: MediaGroup
}

struct Author {
    let name: String
}

struct MediaGroup {
    let title: String
    let description: String
    let thumbnail: FeedThumbnail
    let videoId: String
    let views: String?
}

struct FeedThumbnail: Codable {
    let url: String
    let width: Int
    let height: Int
}

