import Foundation

/// `videoDetails` from the `/player` response playback already fetches. It is
/// the authoritative source for what feed items leave out — TV tiles omit the
/// channel and description, and Shorts sequence entries carry only an ID.
nonisolated struct PlayerVideoDetails: Decodable, Sendable {
    let videoId: String?
    let title: String?
    let author: String?
    let channelId: String?
    let shortDescription: String?
    let lengthSeconds: String?
    let viewCount: String?
}

extension Video {
    /// Fills fields the listing left empty; never overrides what it had.
    func filling(from details: PlayerVideoDetails) -> Video {
        var video = self
        if video.title.isEmpty, let title = details.title { video.title = title }
        if video.channelTitle.isEmpty, let author = details.author { video.channelTitle = author }
        if video.channelId?.isEmpty ?? true { video.channelId = details.channelId }
        if video.description?.isEmpty ?? true { video.description = details.shortDescription }
        if video.duration == nil,
           let seconds = details.lengthSeconds.flatMap(TimeInterval.init), seconds > 0 {
            video.duration = seconds
        }
        if video.viewCount == nil { video.viewCount = details.viewCount.flatMap(Int.init) }
        return video
    }
}
