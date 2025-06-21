//
//  VideoDetail.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 21/06/2025.
//

import Foundation

struct VideoDetail: Codable {
    // Basic video info
    let title: String
    let description: String?
    let views: Int
    let duration: Int
    let likes: Int?
    let dislikes: Int?
    let livestream: Bool?
    
    // Upload info
    let uploaded: Double?
    let uploadDate: String?
    
    // Thumbnails
    let thumbnailUrl: String?
    
    // Channel/Author info
    var uploader: String = "Unknown Channel"
    let uploaderUrl: String?
    let uploaderAvatar: String?
    let uploaderVerified: Bool?
    var uploaderSubscriberCount: Int = 0
    
    // Categories and tags
    let category: String?
    let tags: [String]?
    let visibility: String?
    
    // Additional content
    let subtitles: [CaptionResponse]?
    let chapters: [ChapterResponse]?
    let relatedStreams: [Video]?
    
    // Video streams
    let videoStreams: [VideoStreamResponse]?
    let audioStreams: [AudioStreamResponse]?
    let hls: String?
    let dash: String?
    
    // New properties
     let proxyUrl: String?
     let lbryId: String?
     let license: String?
     let metaInfo: [String]?
     let previewFrames: [PreviewFrame]?
    
    var channelId: String {
        uploaderUrl?.components(separatedBy: "/").last ?? "unknown"
    }
    
    var isLive: Bool {
        livestream ?? (duration == -1)
    }
    
    var isShortVideo: Bool {
        duration <= 61
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
        let suffix = views == 1 ? " view" : " views"
        
        if views >= 1_000_000 {
            return String(format: "%.1fM", Double(views) / 1_000_000) + suffix
        } else if views >= 1_000 {
            return String(format: "%.1fK", Double(views) / 1_000) + suffix
        } else {
            return "\(views)" + suffix
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
        } else if dislikes != -1 {
            return "\(dislikes)"
        } else {
            return nil
        }
    }
    
    var subscribersText: String {
        if uploaderSubscriberCount >= 1_000_000 {
            return String(format: "%.1fM subscribers", Double(uploaderSubscriberCount) / 1_000_000)
        } else if uploaderSubscriberCount >= 1_000 {
            return String(format: "%.1fK subscribers", Double(uploaderSubscriberCount) / 1_000)
        } else {
            return "\(uploaderSubscriberCount) subscribers"
        }
    }
}
