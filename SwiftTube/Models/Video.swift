import Foundation

struct Video: Identifiable, Hashable {
    let id: String
    let title: String
    let author: String
    let duration: TimeInterval
    let published: String
    let views: Int
    let thumbnailURL: URL?
    
    init(
        id: String,
        title: String,
        author: String,
        duration: TimeInterval = 0,
        published: String = "",
        views: Int = 0,
        thumbnailURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.duration = duration
        self.published = published
        self.views = views
        self.thumbnailURL = thumbnailURL
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
}
