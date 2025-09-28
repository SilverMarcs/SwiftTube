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
    var channelTitle: String
    var url: String
    var likeCount: String?          // optional; filled on detail fetch
    var viewCount: String?          // optional
    var commentCount: String?       // optional
    var duration: Int?           // total seconds
    var definition: String?
    var caption: Bool?
    var updatedAt: Date?   // to throttle detail refetch
    var isShort: Bool = false   // determined by duration <= 60 seconds

    @Relationship var channel: Channel?
    @Relationship(inverse: \Comment.video) var comments: [Comment] = []

    init(id: String, title: String, videoDescription: String, thumbnailURL: String, publishedAt: Date, channelTitle: String, url: String, channel: Channel?, viewCount: String? = nil, isShort: Bool = false) {
        self.id = id
        self.title = title
        self.videoDescription = videoDescription
        self.thumbnailURL = thumbnailURL
        self.publishedAt = publishedAt
        self.channelTitle = channelTitle
        self.url = url
        self.channel = channel
        self.viewCount = viewCount
        self.isShort = isShort
    }
}
