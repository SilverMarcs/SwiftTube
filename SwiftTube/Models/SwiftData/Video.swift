// Video.swift
import Foundation

struct Video: Codable, Identifiable, Hashable {
    var id: String          // videoId
    var title: String
    var videoDescription: String
    var thumbnailURL: String
    var publishedAt: Date
    var url: String
    var channel: Channel
    var viewCount: String
    var isShort: Bool
    var likeCount: String?          // optional; filled on detail fetch
    var duration: Int?  // total seconds
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
