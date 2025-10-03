// Video.swift
import Foundation

struct Video: Codable, Identifiable, Hashable {
    var id: String          // videoId
    var title: String
    var videoDescription: String
    var thumbnailURL: String
    var publishedAt: Date
    var url: String
    var viewCount: String
    var likeCount: String?          // optional; filled on detail fetch
    var duration: Int?           // total seconds
    var isShort: Bool   // determined by duration <= 60 seconds
    
    // Embedded channel data instead of separate relationship
    var channel: Channel?

    init(id: String, title: String, videoDescription: String, thumbnailURL: String, publishedAt: Date, url: String, channel: Channel?, viewCount: String = "0", isShort: Bool) {
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

extension Video {
    var watchProgressRatio: Double? {
        guard let duration = duration, duration > 0 else { return nil }
        let progress = UserDefaultsManager.shared.getWatchProgress(videoId: id)
        guard progress > 0 else { return nil }
        return min(progress / Double(duration), 1.0)
    }
    
    func updateWatchProgress(_ seconds: Double) {
        let sanitized = max(0, seconds)
        let finalProgress: Double
        if let duration = duration {
            finalProgress = min(sanitized, Double(duration))
        } else {
            finalProgress = sanitized
        }
        UserDefaultsManager.shared.setWatchProgress(videoId: id, progress: finalProgress)
    }
}
