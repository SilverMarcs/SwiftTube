// Video.swift
import Foundation
import SwiftData

@Model
final class Video {
    @Attribute(.unique) var id: String          // videoId
    var title: String
    var videoDescription: String
    var thumbnailURL: String
    var publishedAt: Date
    var url: String
    var viewCount: String
    var likeCount: String?          // optional; filled on detail fetch
    var duration: Int?           // total seconds
    var isShort: Bool = false   // determined by duration <= 60 seconds

    @Relationship var channel: Channel?
    @Relationship(inverse: \Comment.video) var comments: [Comment] = []

    init(id: String, title: String, videoDescription: String, thumbnailURL: String, publishedAt: Date, url: String, channel: Channel?, viewCount: String = "0", isShort: Bool = false) {
        self.id = id
        self.title = title
        self.videoDescription = videoDescription
        self.thumbnailURL = thumbnailURL
        self.publishedAt = publishedAt
        self.url = url
        self.channel = channel
        self.viewCount = viewCount
        self.isShort = isShort
    }
}
