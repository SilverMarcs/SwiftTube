//
//  VideoLoader.swift
//  Cathode
//
//  Aggregates the user's subscriptions feed. Phase 2a replaces the per-channel
//  RSS poller with InnerTube's `fetchSubscriptions()` — a single authenticated
//  call that returns newest-first videos with view/like counts and durations
//  already populated, so no per-video enrichment step is needed.
//

import SwiftUI

@Observable
final class VideoLoader {

    private(set) var videos: [Video] = []
    private(set) var shortVideos: [Video] = []

    private(set) var isLoading: Bool = false
    private(set) var isLoadingMore: Bool = false
    /// True once a load attempt has completed (success or empty). Lets views
    /// distinguish "still loading" from "loaded — nothing to show".
    private(set) var hasLoaded: Bool = false

    /// Continuation token for the next page of the InnerTube subscriptions feed.
    /// `nil` once the end of the feed has been reached or before the first load.
    private(set) var nextPageToken: String?

    /// In-memory order for shorts (video IDs). Shuffled on first feed load of the
    /// process; subsequent reloads preserve this order so prefetched stream URLs
    /// stay aligned with what the user actually swipes through.
    private var shortsOrder: [String] = []

    /// Reloads the subscriptions feed from scratch.
    /// Falls back to an empty list if the user isn't authenticated yet.
    func loadAllChannelVideos() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let group = try await InnerTubeAPI.shared.fetchSubscriptions()
            nextPageToken = group.nextPageToken

            let savedChannelLookup = Dictionary(
                uniqueKeysWithValues: CloudStoreManager.shared.savedChannels.map { ($0.id, $0) }
            )

            let allVideos: [Video] = group.videos.map { it in
                if let channelId = it.channelId, let savedChannel = savedChannelLookup[channelId] {
                    return Video(it, channel: savedChannel)
                }
                return Video(it)
            }

            // Separate shorts and regular videos. InnerTube already flags shorts
            // (reelItemRenderer); fall back to duration ≤ 60s as a safety net.
            let shorts = allVideos.filter { $0.isShort || ($0.duration.map { $0 > 0 && $0 <= 60 } ?? false) }
            let regular = allVideos.filter { !$0.isShort && !($0.duration.map { $0 > 0 && $0 <= 60 } ?? false) }

            // InnerTube returns newest-first, but sort defensively in case the
            // upstream order ever changes.
            let sortedVideos = regular.sorted { $0.publishedAt > $1.publishedAt }

            withAnimation {
                self.videos = sortedVideos
            }
            self.shortVideos = applyStableShuffle(to: shorts)
            self.hasLoaded = true
        } catch {
            print("Error loading subscriptions: \(error)")
            self.videos = []
            self.shortVideos = []
            self.hasLoaded = true
        }
    }

    /// Loads the next page of the subscriptions feed, appending to `videos`/`shortVideos`.
    /// No-ops when there is no continuation token or a page load is already in flight.
    func loadMore() async {
        guard let token = nextPageToken, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let group = try await InnerTubeAPI.shared.fetchSubscriptions(continuationToken: token)
            nextPageToken = group.nextPageToken

            let savedChannelLookup = Dictionary(
                uniqueKeysWithValues: CloudStoreManager.shared.savedChannels.map { ($0.id, $0) }
            )
            let newVideos: [Video] = group.videos.map { it in
                if let channelId = it.channelId, let savedChannel = savedChannelLookup[channelId] {
                    return Video(it, channel: savedChannel)
                }
                return Video(it)
            }
            let shorts = newVideos.filter { $0.isShort || ($0.duration.map { $0 > 0 && $0 <= 60 } ?? false) }
            let regular = newVideos.filter { !$0.isShort && !($0.duration.map { $0 > 0 && $0 <= 60 } ?? false) }

            let existingIds = Set(self.videos.map(\.id))
            let regularNew = regular.filter { !existingIds.contains($0.id) }
            self.videos.append(contentsOf: regularNew)

            let existingShortIds = Set(self.shortVideos.map(\.id))
            let shortsNew = shorts.filter { !existingShortIds.contains($0.id) }
            self.shortVideos.append(contentsOf: shortsNew)
        } catch {
            print("Error loading more subscriptions: \(error)")
        }
    }

    func getMostRecentHistoryVideo() -> Video? {
        CloudStoreManager.shared.historyVideos.first
    }

    private func applyStableShuffle(to shorts: [Video]) -> [Video] {
        if shortsOrder.isEmpty {
            let shuffled = shorts.shuffled()
            shortsOrder = shuffled.map(\.id)
            return shuffled
        }
        let rank = Dictionary(uniqueKeysWithValues: shortsOrder.enumerated().map { ($1, $0) })
        let known = shorts
            .filter { rank[$0.id] != nil }
            .sorted { rank[$0.id]! < rank[$1.id]! }
        let new = shorts.filter { rank[$0.id] == nil }.shuffled()
        let merged = known + new
        shortsOrder = merged.map(\.id)
        return merged
    }
}
