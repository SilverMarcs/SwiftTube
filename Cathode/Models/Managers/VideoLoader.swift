//
//  VideoLoader.swift
//  Cathode
//
//  Aggregates the user's home feed via InnerTube's `fetchHome()` —
//  YouTube's `FEwhat_to_watch` shelf (subs interleaved with recommendations,
//  mixes, etc.) flattened into a single newest-first list.
//

import SwiftUI

@Observable
final class VideoLoader {

    private(set) var videos: [Video] = []
    private(set) var shortVideos: [Video] = []

    /// Re-entry guard for `loadMore()`.
    private var isLoadingMore: Bool = false

    /// Continuation token for the next page of the InnerTube home feed.
    /// `nil` once the end of the feed has been reached or before the first load.
    private(set) var nextPageToken: String?

    /// In-memory order for shorts (video IDs). Shuffled on first feed load of the
    /// process; subsequent reloads preserve this order so prefetched stream URLs
    /// stay aligned with what the user actually swipes through.
    private var shortsOrder: [String] = []

    /// Whether to use the recommendations-rich home feed (`FEwhat_to_watch`) or
    /// the subscriptions-only feed (`FEsubscriptions`). Driven by the
    /// "Include recommendations" toggle in Settings.
    private var useHomeFeed: Bool {
        UserDefaults.standard.object(forKey: "useHomeFeed") as? Bool ?? true
    }

    private func fetchFeed(continuationToken: String? = nil) async throws -> VideoGroup {
        if useHomeFeed {
            return try await InnerTubeAPI.shared.fetchHome(continuationToken: continuationToken)
        } else {
            return try await InnerTubeAPI.shared.fetchSubscriptions(continuationToken: continuationToken)
        }
    }

    /// Reloads the feed from scratch.
    func loadAllChannelVideos() async {
        do {
            let group = try await fetchFeed()
            nextPageToken = group.nextPageToken

            let (shorts, regular) = splitShorts(group.videos)
            let regularSorted = useHomeFeed
                ? regular
                : regular.sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }

            withAnimation {
                self.videos = regularSorted
            }
            self.shortVideos = applyStableShuffle(to: shorts)
        } catch {
            print("Error loading feed: \(error)")
        }
    }

    /// Loads the next page of the feed, appending to `videos`/`shortVideos`.
    /// No-ops when there is no continuation token or a page load is already in flight.
    func loadMore() async {
        guard let token = nextPageToken, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let group = try await fetchFeed(continuationToken: token)
            nextPageToken = group.nextPageToken

            let (shorts, regular) = splitShorts(group.videos)

            let existingIds = Set(self.videos.map(\.id))
            let regularNew = regular.filter { !existingIds.contains($0.id) }
            self.videos.append(contentsOf: regularNew)

            let existingShortIds = Set(self.shortVideos.map(\.id))
            let shortsNew = shorts.filter { !existingShortIds.contains($0.id) }
            self.shortVideos.append(contentsOf: shortsNew)
        } catch {
            print("Error loading more feed: \(error)")
        }
    }

    @MainActor
    func getMostRecentHistoryVideo() -> Video? {
        LibraryStore.shared.history.first
    }

    private func splitShorts(_ all: [Video]) -> (shorts: [Video], regular: [Video]) {
        let shorts = all.filter { $0.isShort || ($0.duration.map { $0 > 0 && $0 <= 60 } ?? false) }
        let regular = all.filter { !$0.isShort && !($0.duration.map { $0 > 0 && $0 <= 60 } ?? false) }
        return (shorts, regular)
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
