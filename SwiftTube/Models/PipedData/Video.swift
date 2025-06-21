import Foundation

struct Video: Codable, Equatable, Hashable, Identifiable {
    let url: String
    let title: String
    var duration: Int = 0
    let type: String?
    let thumbnail: String?
    var uploaded: Double = 0
    var uploaderVerified: Bool = false
    var uploaderName: String = "Unknown Channel"
    let uploaderUrl: String?
    let uploaderAvatar: String?
    var isShort: Bool = false
    var views: Int = 0
    
    static func == (lhs: Video, rhs: Video) -> Bool {
        return lhs.url == rhs.url
    }
    
    var id: String {
        // strip the URL to get the video ID
//        /watch?v=eMeJsm56NOM
        if let videoId = url.split(separator: "=").last {
            return String(videoId)
        }
        return UUID().uuidString // fallback in case URL is malformed
    }

    var thumbnailURL: URL {
        return URL(string: thumbnail ?? "https://picsum.photos/seed/picsum/200/300")!
    }
    
    var durationText: String {
//        guard let duration = duration else { return "0:00" }
        
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
        let suffix = views == 1 ? " view" : " views"
        
        if views >= 1_000_000 {
            return String(format: "%.1fM", Double(views) / 1_000_000) + suffix
        } else if views >= 1_000 {
            return String(format: "%.1fK", Double(views) / 1_000) + suffix
        } else {
            return "\(views)" + suffix
        }
    }
}
