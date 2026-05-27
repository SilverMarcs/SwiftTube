import Foundation

struct TopShelfItemSnapshot: Codable, Hashable {
    let id: String
    let title: String
    let imageURL: URL
    let summary: String?
    let genre: String?
    let channelTitle: String?
    let creationDate: Date?
    let durationSeconds: Double?
    let viewCount: Int?
}

enum TopShelfCache {
    private static let appGroupID = "group.com.SilverMarcs.SwiftTube"
    private static let itemsKey = "TopShelfRecommendedItems"

    static func load() -> [TopShelfItemSnapshot] {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return [] }
        guard let data = defaults.data(forKey: itemsKey) else { return [] }
        return (try? JSONDecoder().decode([TopShelfItemSnapshot].self, from: data)) ?? []
    }
}
