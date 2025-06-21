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
    let uploader: String?
    let uploaderUrl: String?
    let uploaderAvatar: String?
    let uploaderVerified: Bool?
    let uploaderSubscriberCount: Int?
    
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
    
    var authorName: String {
        "uploaderName" ?? uploader ?? ""
    }
    
    var thumbnailURL: String? {
        "thumbnail" ?? thumbnailUrl
    }
    
    var isLive: Bool {
        livestream ?? (duration == -1)
    }
    
    var isShortVideo: Bool {
        duration <= 61
    }
//    
//    var publishedDateString: String {
//        if let uploadedTimestamp = uploaded, uploadedTimestamp > 0 {
//            let date = Date(timeIntervalSince1970: uploadedTimestamp / 1000)
//            return date.relativeTime
//        } else if let uploadedString = uploadedDate ?? uploadDate {
//            return uploadedString
//        }
//        return ""
//    }
//    
//    var publishedDate: Date? {
//        if let uploadedTimestamp = uploaded, uploadedTimestamp > 0 {
//            return Date(timeIntervalSince1970: uploadedTimestamp / 1000)
//        } else if let dateString = uploadedDate ?? uploadDate {
//            let formatter = ISO8601DateFormatter()
//            formatter.formatOptions = [.withInternetDateTime]
//            return formatter.date(from: dateString)
//        }
//        return nil
//    }
    
    private func extractVideoId(from url: String) -> String {
        if url.contains("watch?v=") {
            let components = url.components(separatedBy: "watch?v=")
            if components.count > 1 {
                return String(components[1].prefix(11))
            }
        }
        return url
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
    
//    var subscribersText: String {
//        if uploaderSubscriberCount >= 1_000_000 {
//            return String(format: "%.1fM subscribers", Double(uploaderSubscriberCount) / 1_000_000)
//        } else if uploaderSubscriberCount >= 1_000 {
//            return String(format: "%.1fK subscribers", Double(uploaderSubscriberCount) / 1_000)
//        } else {
//            return "\(uploaderSubscriberCount) subscribers"
//        }
//    }
}

struct ChapterResponse: Codable {
    let title: String?
    let image: String?
    let start: Double?
    
    func toChapter() -> Chapter? {
        guard let title = title, let start = start else { return nil }
        return Chapter(
            title: title,
            startTime: start,
            thumbnailURL: image.flatMap { URL(string: $0) }
        )
    }
}

struct CaptionResponse: Codable {
    let url: String?
    let mimeType: String?
    let name: String?
    let code: String?
    let autoGenerated: Bool?
}

struct VideoStreamResponse: Codable {
    let url: String?
    let format: String?
    let quality: String?
    let mimeType: String?
    let codec: String?
    let audioTrackId: String?
    let audioTrackName: String?
    let videoOnly: Bool?
    let itag: Int?
    let bitrate: Int?
    let initStart: Int?
    let initEnd: Int?
    let indexStart: Int?
    let indexEnd: Int?
    let width: Int?
    let height: Int?
    let fps: Int?
    let contentLength: Int?
}

struct AudioStreamResponse: Codable {
    let url: String?
    let format: String?
    let quality: String?
    let mimeType: String?
    let codec: String?
    let audioTrackId: String?
    let audioTrackName: String?
    let audioTrackType: String?
    let audioTrackLocale: String?
    let videoOnly: Bool?
    let itag: Int?
    let bitrate: Int?
    let initStart: Int?
    let initEnd: Int?
    let indexStart: Int?
    let indexEnd: Int?
    let loudness: Double?
    let contentLength: Int?
}

struct PreviewFrame: Codable {
    let urls: [String]?
    let frameHeight: Int?
    let totalCount: Int?
    let framesPerPageY: Int?
    let frameWidth: Int?
    let durationPerFrame: Int?
    let framesPerPageX: Int?
}
