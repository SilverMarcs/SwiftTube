//
//  VideoLoader.swift
//  Cathode
//
//  Aggregates the user's subscriptions feed via InnerTube's `fetchSubscriptions()`
//  — a single authenticated call that returns newest-first videos with view
//  counts and durations already populated.
//

import SwiftUI

enum FeedMode {
    case subscriptions
    case recommendations
}

@MainActor
@Observable
final class VideoLoader {

    private(set) var videos: [Video] = []
    private(set) var shortVideos: [Video] = []
    private(set) var recommendations: [Video] = []
    /// Recommendations grouped as YouTube's home shelves (one `.row` per shelf),
    /// rendered as horizontal carousels. `recommendations` above is the flattened
    /// form kept for the signed-out grid fallback and the TopShelf extension.
    private(set) var recommendationRows: [VideoGroup] = []

    var mode: FeedMode = YTTVAuthManager.shared.isSignedIn ? .subscriptions : .recommendations

    /// Re-entry guard for `loadMore()`.
    private var isLoadingMore: Bool = false

    /// Per-shelf re-entry guard for `loadMoreInShelf(_:)`, keyed by shelf id.
    private var shelvesLoadingMore: Set<VideoGroup.ID> = []

    /// Re-entry guards so the overlapping cold-launch / auth / tab-appear triggers
    /// coalesce into a single fetch instead of reloading the whole feed twice.
    private var isLoadingChannelVideos = false
    private var isLoadingRecommendations = false

    /// Continuation token for the next page of the InnerTube subscriptions feed.
    /// `nil` once the end of the feed has been reached or before the first load.
    private(set) var nextPageToken: String?

    /// In-memory order for shorts (video IDs). Shuffled on first feed load of the
    /// process; subsequent reloads preserve this order so prefetched stream URLs
    /// stay aligned with what the user actually swipes through.
    private var shortsOrder: [String] = []

    /// Reloads the subscriptions feed from scratch.
    func loadAllChannelVideos() async {
        guard YTTVAuthManager.shared.isSignedIn else { return }
        if isLoadingChannelVideos { return }
        isLoadingChannelVideos = true
        defer { isLoadingChannelVideos = false }
        do {
            let group = try await InnerTubeAPI.shared.fetchSubscriptions()
            nextPageToken = group.nextPageToken

            let (shorts, regular) = splitShorts(group.videos)
            let sortedVideos = regular.sorted {
                ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast)
            }

            withAnimation {
                self.videos = sortedVideos.removingDuplicates()
            }
            self.shortVideos = applyStableShuffle(to: shorts)
        } catch {
            print("Error loading subscriptions: \(error)")
        }
    }

    func loadRecommendations() async {
        if isLoadingRecommendations { return }
        isLoadingRecommendations = true
        defer { isLoadingRecommendations = false }
        do {
            let rows = try await InnerTubeAPI.shared.fetchAllRecommendationRows()
            // Strip Shorts from each shelf, dedupe within a shelf, drop empty shelves.
            let cleaned: [VideoGroup] = rows.compactMap { group in
                let (_, regular) = splitShorts(group.videos)
                let deduped = regular.removingDuplicates()
                guard !deduped.isEmpty else { return nil }
                var g = group
                g.videos = deduped
                return g
            }
            // Flat list for the signed-out grid fallback + TopShelf: every shelf's
            // videos, globally deduped so a video shared across shelves appears once.
            let flat = cleaned.flatMap(\.videos).removingDuplicates()
            withAnimation {
                self.recommendationRows = cleaned
                self.recommendations = flat
            }
            TopShelfCache.save(videos: flat)
        } catch {
            print("Error loading recommendations: \(error)")
        }
    }

    /// Loads the next batch of items for a single recommendation shelf (horizontal
    /// pagination), appending new videos to that shelf and advancing its token.
    /// No-ops when the shelf has no continuation token or a load is already in flight.
    func loadMoreInShelf(_ shelfID: VideoGroup.ID) async {
        guard !shelvesLoadingMore.contains(shelfID),
              let idx = recommendationRows.firstIndex(where: { $0.id == shelfID }),
              let token = recommendationRows[idx].shelfContinuationToken, !token.isEmpty
        else { return }
        shelvesLoadingMore.insert(shelfID)
        defer { shelvesLoadingMore.remove(shelfID) }
        do {
            let more = try await InnerTubeAPI.shared.fetchHomeShelfContinuation(continuationToken: token)
            let (_, regular) = splitShorts(more.videos)
            // The shelf may have been rebuilt (refresh) while this was in flight.
            guard let i = recommendationRows.firstIndex(where: { $0.id == shelfID }) else { return }
            let existing = Set(recommendationRows[i].videos.map(\.id))
            let newOnes = regular.removingDuplicates().filter { !existing.contains($0.id) }
            recommendationRows[i].videos.append(contentsOf: newOnes)
            recommendationRows[i].shelfContinuationToken = more.nextPageToken
        } catch {
            print("Error loading more in shelf: \(error)")
        }
    }

    func clearSubscriptions() {
        self.videos = []
        self.shortVideos = []
        self.nextPageToken = nil
    }

    /// Loads the next page of the subscriptions feed, appending to `videos`/`shortVideos`.
    /// No-ops when there is no continuation token or a page load is already in flight.
    func loadMore() async {
        guard YTTVAuthManager.shared.isSignedIn else { return }
        guard let token = nextPageToken, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let group = try await InnerTubeAPI.shared.fetchSubscriptions(continuationToken: token)
            nextPageToken = group.nextPageToken

            let (shorts, regular) = splitShorts(group.videos)

            let existingIds = Set(self.videos.map(\.id))
            let regularNew = regular
                .removingDuplicates()
                .filter { !existingIds.contains($0.id) }
            self.videos.append(contentsOf: regularNew)

            let existingShortIds = Set(self.shortVideos.map(\.id))
            let shortsNew = shorts.filter { !existingShortIds.contains($0.id) }
            self.shortVideos.append(contentsOf: shortsNew)
        } catch {
            print("Error loading more subscriptions: \(error)")
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
