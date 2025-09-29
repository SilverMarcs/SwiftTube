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
    var isShort: Bool   // determined by duration <= 60 seconds
    var isWatchLater: Bool = false  // user's watch later list
    var watchProgressSeconds: Double = 0
    var lastWatchedAt: Date? = nil  // for history tracking

    @Relationship var channel: Channel?
    @Relationship(inverse: \Comment.video) var comments: [Comment] = []

    init(id: String, title: String, videoDescription: String, thumbnailURL: String, publishedAt: Date, url: String, channel: Channel?, viewCount: String = "0", isShort: Bool, isWatchLater: Bool = false) {
        self.id = id
        self.title = title
        self.videoDescription = videoDescription
        self.thumbnailURL = thumbnailURL
        self.publishedAt = publishedAt
        self.url = url
        self.channel = channel
        self.viewCount = viewCount
        self.isShort = isShort
        self.isWatchLater = isWatchLater
        self.watchProgressSeconds = 0
        self.lastWatchedAt = nil
    }
}

extension Video {
    var watchProgressRatio: Double? {
        guard let duration = duration, duration > 0, watchProgressSeconds > 0 else { return nil }
        return min(watchProgressSeconds / Double(duration), 1.0)
    }
    
    func updateWatchProgress(_ seconds: Double) {
        let sanitized = max(0, min(seconds, Double(duration ?? Int.max)))
        guard abs(watchProgressSeconds - sanitized) > 1 else { return }
        watchProgressSeconds = sanitized
    }
}
