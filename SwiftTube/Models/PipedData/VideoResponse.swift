import Foundation

struct VideoResponse: Codable {
    let url: String
    let title: String
    let uploaderName: String?
    let uploader: String?
    let author: String?
    let duration: TimeInterval?
    let views: Int?
    let uploaded: Double?
    let uploadedDate: String?
    let uploadDate: String?
    let thumbnail: String?
    let thumbnailUrl: String?
    
    // Additional fields from Piped API
    let description: String?
    let likes: Int?
    let dislikes: Int?
    let livestream: Bool?
    let isShort: Bool?
    let uploaderUrl: String?
    let uploaderAvatar: String?
    let uploaderSubscriberCount: Int?
    let avatarUrl: String?
    let avatar: String?
    
    // Computed properties to handle multiple field names
    var authorName: String {
        return uploaderName ?? uploader ?? author ?? ""
    }
    
    var channelId: String {
        uploaderUrl?.components(separatedBy: "/").last ?? "unknown"
    }
    
    var videoDuration: TimeInterval {
        return duration ?? 0
    }
    
    var videoViews: Int {
        return views ?? 0
    }
    
    var thumbnailURLString: String? {
        return thumbnail ?? thumbnailUrl
    }
    
    var avatarURLString: String? {
        return uploaderAvatar ?? avatarUrl ?? avatar
    }
    
    var isLive: Bool {
        return livestream ?? (duration == -1)
    }
    
    var isShortVideo: Bool {
        return isShort ?? ((duration ?? 0) <= 61)
    }
    
    var uploadedDateString: String {
        if let uploadedTimestamp = uploaded, uploadedTimestamp > 0 {
            let date = Date(timeIntervalSince1970: uploadedTimestamp / 1000)
            return date.relativeTime
        } else if let uploadedString = uploadedDate ?? uploadDate {
            return uploadedString
        }
        return ""
    }
    
    var publishedDate: Date? {
        if let uploadedTimestamp = uploaded, uploadedTimestamp > 0 {
            return Date(timeIntervalSince1970: uploadedTimestamp / 1000)
        } else if let dateString = uploadedDate ?? uploadDate {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: dateString)
        }
        return nil
    }
    
    // Convert to Video model
    func toVideo() -> Video? {
        let videoId = extractVideoId(from: url)
        
        let video = Video(
            id: videoId,
            title: title,
            author: authorName,
            duration: videoDuration,
            published: uploadedDateString,
            views: videoViews,
            thumbnailURL: thumbnailURLString.flatMap { URL(string: $0) },
            description: description,
            likes: likes,
            dislikes: dislikes,
            isLive: isLive,
            isShort: isShortVideo,
            publishedAt: publishedDate,
            channelId: channelId,
            channelSubscriberCount: uploaderSubscriberCount
        )
        
        return video
    }
    
    private func extractVideoId(from url: String) -> String {
        if url.contains("watch?v=") {
            let components = url.components(separatedBy: "watch?v=")
            if components.count > 1 {
                return String(components[1].prefix(11)) // YouTube video IDs are 11 characters
            }
        }
        return url
    }
}
