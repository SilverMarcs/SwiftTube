import Foundation

struct Channel: Identifiable, Hashable {
    let id: String
    let name: String
    let thumbnailURL: URL?
    let subscribersCount: Int?
    
    init(
        id: String,
        name: String,
        thumbnailURL: URL? = nil,
        subscribersCount: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.thumbnailURL = thumbnailURL
        self.subscribersCount = subscribersCount
    }
    
    var subscribersText: String? {
        guard let count = subscribersCount else { return nil }
        
        if count >= 1_000_000 {
            return String(format: "%.1fM subscribers", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK subscribers", Double(count) / 1_000)
        } else {
            return "\(count) subscribers"
        }
    }
}
