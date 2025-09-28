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

    @Relationship var channel: Channel?
    @Relationship(inverse: \Comment.video) var comments: [Comment] = []

    init(id: String, title: String, videoDescription: String, thumbnailURL: String, publishedAt: Date, channelTitle: String, url: String, channel: Channel?) {
        self.id = id
        self.title = title
        self.videoDescription = videoDescription
        self.thumbnailURL = thumbnailURL
        self.publishedAt = publishedAt
        self.channelTitle = channelTitle
        self.url = url
        self.channel = channel
    }
}
