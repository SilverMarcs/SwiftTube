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
    var viewCountValue: UInt64? {
        UInt64(viewCount)
    }
    
    var likeCountValue: UInt64? {
        likeCount.flatMap(UInt64.init)
    }
    
    var watchProgressRatio: Double? {
        guard let duration = duration, duration > 0 else { return nil }
        let progress = CloudStoreManager.shared.getWatchProgress(videoId: id)
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
        // Avoid overwriting an existing positive progress with 0.
        // The YouTube iframe player sometimes reports currentTime as 0 when playback ends,
        // which would otherwise clear a saved watched progress. If there's already a
        // saved positive progress for this video, do not overwrite it with 0 here.
        let previousProgress = CloudStoreManager.shared.getWatchProgress(videoId: id)
        if finalProgress == 0 && previousProgress > 0 {
            return
        }

        CloudStoreManager.shared.setWatchProgress(videoId: id, progress: finalProgress)
    }
}
