import Foundation
#if canImport(TVServices)
import TVServices
#endif

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
    private static let maxItems = 10

    static func save(videos: [Video]) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }

        let snapshots = videos.compactMap { video -> TopShelfItemSnapshot? in
            guard let imageURL = video.maxresThumbnailURL ?? video.thumbnailURL ?? video.mqThumbnailURL else { return nil }
            return TopShelfItemSnapshot(
                id: video.id,
                title: video.deArrowTitle ?? video.title,
                imageURL: imageURL,
                summary: video.description,
                genre: nil,
                channelTitle: video.channelTitle,
                creationDate: video.publishedAt,
                durationSeconds: video.duration,
                viewCount: video.viewCount
            )
        }
        let limited = Array(snapshots.shuffled().prefix(maxItems))

        do {
            let data = try JSONEncoder().encode(limited)
            defaults.set(data, forKey: itemsKey)
            #if canImport(TVServices)
            TVTopShelfContentProvider.topShelfContentDidChange()
            #endif
        } catch {
            print("Error caching Top Shelf items: \(error)")
        }
    }
}
