//import Foundation
//
//struct VideoDetail: Identifiable, Hashable {
//    // Basic video properties (from Video)
//    let id: String
//    let title: String
//    let author: String
//    let duration: TimeInterval
//    let published: String
//    let views: Int
//    let thumbnailURL: URL?
//    let isLive: Bool
//    let isShort: Bool
//    let publishedAt: Date?
//    let channelId: String?
//    let channelSubscriberCount: Int?
//    
//    // Detailed properties (from video details endpoint)
//    let description: String?
//    let likes: Int?
//    let dislikes: Int?
//    let chapters: [Chapter]
//    let captions: [Caption]
//    let relatedVideos: [Video]
//    
//    // Computed properties
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
//    
//    var likesText: String? {
//        guard let likes = likes else { return nil }
//        if likes >= 1_000_000 {
//            return String(format: "%.1fM", Double(likes) / 1_000_000)
//        } else if likes >= 1_000 {
//            return String(format: "%.1fK", Double(likes) / 1_000)
//        } else {
//            return "\(likes)"
//        }
//    }
//    
//    var dislikesText: String? {
//        guard let dislikes = dislikes else { return nil }
//        if dislikes >= 1_000_000 {
//            return String(format: "%.1fM", Double(dislikes) / 1_000_000)
//        } else if dislikes >= 1_000 {
//            return String(format: "%.1fK", Double(dislikes) / 1_000)
//        } else {
//            return "\(dislikes)"
//        }
//    }
//}
