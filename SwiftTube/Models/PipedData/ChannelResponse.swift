import Foundation

struct ChannelResponse: Codable {
    let url: String
    let name: String
    let subscriberCount: Int?
    let subscribers: Int?
    let uploaderSubscriberCount: Int?
    let avatar: String?
    let avatarUrl: String?
    let uploaderAvatar: String?
    
    // Additional fields from Piped API
    let description: String?
    let verified: Bool?
    let relatedStreams: [VideoResponse]?
    
    // Computed properties to handle multiple field names
    var channelSubscriberCount: Int? {
        return subscriberCount ?? subscribers ?? uploaderSubscriberCount
    }
    
    var avatarURLString: String? {
        return avatar ?? avatarUrl ?? uploaderAvatar
    }
    
    // Convert to Channel model
    func toChannel() -> Channel? {
        let channelId = extractChannelId(from: url)
        
        let channel = Channel(
            id: channelId,
            name: name,
            thumbnailURL: avatarURLString.flatMap { URL(string: $0) },
            subscribersCount: channelSubscriberCount,
            description: description,
            verified: verified ?? false,
            videos: [] // TODO: 
        )
        
        return channel
    }
    
    private func extractChannelId(from url: String) -> String {
        if url.contains("/channel/") {
            let components = url.components(separatedBy: "/channel/")
            if components.count > 1 {
                return components[1]
            }
        }
        return url
    }
}
