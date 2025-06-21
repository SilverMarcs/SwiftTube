import Foundation

struct VideoResponse: Codable, Equatable, Hashable, Identifiable {
    let url: String
    let title: String
    let duration: Int?
    let type: String?
    let thumbnail: String?
    let uploaded: Double?
    let uploaderVerified: Bool?
    let uploaderName: String?
    let uploaderUrl: String?
    let uploaderAvatar: String?
    let isShort: Bool?
    let views: Int?
    
    static func == (lhs: VideoResponse, rhs: VideoResponse) -> Bool {
        return lhs.url == rhs.url
    }
    
    var id : String {
        return url
    }
    
    // Keep only computed properties that work with available fields
    var channelId: String {
        uploaderUrl?.components(separatedBy: "/").last ?? "unknown"
    }
    
    var publishedDate: Date? {
        if uploaded ?? 0 > 0 {
            return Date(timeIntervalSince1970: uploaded ?? 0 / 1000)
        }
        
        return nil
    }
    
    var thumbnailURL: URL {
        // rteurn dummy URL if thumbnail is nil
//        https://picsum.photos/seed/picsum/200/300
        return URL(string: thumbnail ?? "https://picsum.photos/seed/picsum/200/300")!
    }
    
    
    // Keep toVideo since it only uses available fields
//    func toVideo() -> Video? {
//        let videoId = extractVideoId(from: url)
//        
//        let video = Video(
//            id: videoId,
//            title: title,
//            author: uploaderName,
//            duration: duration,
//            views: views,
//            thumbnailURL: URL(string: thumbnail),
//            isLive: false,
//            isShort: isShort,
//            publishedAt: publishedDate,
//            channelId: channelId,
//            channelSubscriberCount: nil
//        )
//        
//        return video
//    }
//
    
    var durationText: String {
        guard let duration = duration else { return "0:00" }
        
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
        guard let views = views else { return "0 views" }
        
         if views >= 1_000_000 {
             return String(format: "%.1fM", Double(views) / 1_000_000)
         } else if views >= 1_000 {
             return String(format: "%.1fK", Double(views) / 1_000)
         } else {
             return "\(views)"
         }
     }
    
    private func extractVideoId(from url: String) -> String {
        if url.contains("watch?v=") {
            let components = url.components(separatedBy: "watch?v=")
            if components.count > 1 {
                return String(components[1].prefix(11))
            }
        }
        return url
    }
}
