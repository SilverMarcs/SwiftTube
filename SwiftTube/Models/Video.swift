import Foundation

struct Video: Identifiable, Hashable {
    let id: String
    let title: String
    let author: String
    let duration: TimeInterval
    let published: String
    let views: Int
    let thumbnailURL: URL?
    
    // Additional fields from Piped API
    let description: String?
    let likes: Int?
    let dislikes: Int?
    let isLive: Bool
    let isShort: Bool
    let publishedAt: Date?
    let channelId: String?
    let channelSubscriberCount: Int?
    let chapters: [Chapter]
    let captions: [Caption]
    let relatedVideos: [Video]
    
    init(
        id: String,
        title: String,
        author: String,
        duration: TimeInterval = 0,
        published: String = "",
        views: Int = 0,
        thumbnailURL: URL? = nil,
        description: String? = nil,
        likes: Int? = nil,
        dislikes: Int? = nil,
        isLive: Bool = false,
        isShort: Bool = false,
        publishedAt: Date? = nil,
        channelId: String? = nil,
        channelSubscriberCount: Int? = nil,
        chapters: [Chapter] = [],
        captions: [Caption] = [],
        relatedVideos: [Video] = []
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.duration = duration
        self.published = published
        self.views = views
        self.thumbnailURL = thumbnailURL
        self.description = description
        self.likes = likes
        self.dislikes = dislikes
        self.isLive = isLive
        self.isShort = isShort
        self.publishedAt = publishedAt
        self.channelId = channelId
        self.channelSubscriberCount = channelSubscriberCount
        self.chapters = chapters
        self.captions = captions
        self.relatedVideos = relatedVideos
    }
    
    var durationText: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    var viewsText: String {
        if views >= 1_000_000 {
            return String(format: "%.1fM", Double(views) / 1_000_000)
        } else if views >= 1_000 {
            return String(format: "%.1fK", Double(views) / 1_000)
        } else {
            return "\(views)"
        }
    }
    
    var likesText: String? {
        guard let likes = likes else { return nil }
        if likes >= 1_000_000 {
            return String(format: "%.1fM", Double(likes) / 1_000_000)
        } else if likes >= 1_000 {
            return String(format: "%.1fK", Double(likes) / 1_000)
        } else {
            return "\(likes)"
        }
    }
    
    var dislikesText: String? {
        guard let dislikes = dislikes else { return nil }
        if dislikes >= 1_000_000 {
            return String(format: "%.1fM", Double(dislikes) / 1_000_000)
        } else if dislikes >= 1_000 {
            return String(format: "%.1fK", Double(dislikes) / 1_000)
        } else {
            return "\(dislikes)"
        }
    }
}
