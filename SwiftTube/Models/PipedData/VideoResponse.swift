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
    
    // Computed properties to handle multiple field names
    var authorName: String {
        return uploaderName ?? uploader ?? author ?? ""
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
    
    var uploadedDateString: String {
        if let uploadedTimestamp = uploaded, uploadedTimestamp > 0 {
            let date = Date(timeIntervalSince1970: uploadedTimestamp / 1000)
            return date.relativeTime
        } else if let uploadedString = uploadedDate ?? uploadDate {
            return uploadedString
        }
        return ""
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
            thumbnailURL: thumbnailURLString.flatMap { URL(string: $0) }
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
