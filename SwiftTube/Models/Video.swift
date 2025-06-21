import Foundation

//struct Video: Identifiable, Hashable {
//    let id: String
//    let title: String
//    let author: String
//    let duration: TimeInterval
//    let published: String
//    let views: Int
//    let thumbnailURL: URL?
//    
//    // Basic fields from feed API
//    let isLive: Bool
//    let isShort: Bool
//    let publishedAt: Date?
//    let channelId: String?
//    let channelSubscriberCount: Int?
//    
//    init(
//        id: String,
//        title: String,
//        author: String,
//        duration: TimeInterval = 0,
//        published: String = "",
//        views: Int = 0,
//        thumbnailURL: URL? = nil,
//        isLive: Bool = false,
//        isShort: Bool = false,
//        publishedAt: Date? = nil,
//        channelId: String? = nil,
//        channelSubscriberCount: Int? = nil
//    ) {
//        self.id = id
//        self.title = title
//        self.author = author
//        self.duration = duration
//        self.published = published
//        self.views = views
//        self.thumbnailURL = thumbnailURL
//        self.isLive = isLive
//        self.isShort = isShort
//        self.publishedAt = publishedAt
//        self.channelId = channelId
//        self.channelSubscriberCount = channelSubscriberCount
//    }
//    
//    var durationText: String {
//        let hours = Int(duration) / 3600
//        let minutes = Int(duration) % 3600 / 60
//        let seconds = Int(duration) % 60
//        
//        if hours > 0 {
//            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
//        } else {
//            return String(format: "%d:%02d", minutes, seconds)
//        }
//    }
//    
//    var viewsText: String {
//        if views >= 1_000_000 {
//            return String(format: "%.1fM", Double(views) / 1_000_000)
//        } else if views >= 1_000 {
//            return String(format: "%.1fK", Double(views) / 1_000)
//        } else {
//            return "\(views)"
//        }
//    }
//}
