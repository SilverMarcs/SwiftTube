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

    /// Continuation token for the next page of the Shorts feed (reel_watch_sequence).
    private var shortsPageToken: String?
    /// The in-flight initial Shorts fetch, so the cold-launch prefetch and the
    /// Shorts-tab-appear trigger coalesce onto one request: the tab awaits the
    /// launch prefetch instead of racing it (which flashed an empty state).
    private var shortsLoadTask: Task<Void, Never>?
    private var isLoadingMoreShorts = false

    /// Reloads the subscriptions feed from scratch. Shorts are a separate feed —
    /// subscription Shorts are dropped here so they don't clutter the Feed grid.
    func loadAllChannelVideos() async {
        guard YTTVAuthManager.shared.isSignedIn else { return }
        if isLoadingChannelVideos { return }
        isLoadingChannelVideos = true
        defer { isLoadingChannelVideos = false }
        do {
            let group = try await InnerTubeAPI.shared.fetchSubscriptions()
            nextPageToken = group.nextPageToken

            let (_, regular) = splitShorts(group.videos)
            let sortedVideos = regular.sorted {
                ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast)
            }

            withAnimation {
                self.videos = sortedVideos.removingDuplicates()
            }
        } catch {
            print("Error loading subscriptions: \(error)")
        }
    }

    /// Loads the personalised "For You" Shorts feed: the home Shorts shelf first,
    /// then endless `reel_watch_sequence` pages via `loadMoreShorts()`.
    func loadShorts() async {
        if let existing = shortsLoadTask {
            await existing.value
            return
        }
        let task = Task { @MainActor in
            do {
                let group = try await InnerTubeAPI.shared.fetchShorts()
                self.shortVideos = group.videos.removingDuplicates()
                self.shortsPageToken = group.nextPageToken
            } catch {
                print("Error loading shorts: \(error)")
            }
        }
        shortsLoadTask = task
        await task.value
        shortsLoadTask = nil
    }

    /// Appends the next page of the Shorts feed. No-op when exhausted or already loading.
    func loadMoreShorts() async {
        if let existing = shortsLoadTask { await existing.value }
        guard let token = shortsPageToken, !isLoadingMoreShorts else { return }
        isLoadingMoreShorts = true
        defer { isLoadingMoreShorts = false }
        do {
            let group = try await InnerTubeAPI.shared.fetchShortsMore(continuationToken: token)
            shortsPageToken = group.nextPageToken
            let existing = Set(shortVideos.map(\.id))
            shortVideos.append(contentsOf: group.videos.filter { !existing.contains($0.id) })
        } catch {
            print("Error loading more shorts: \(error)")
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
        self.nextPageToken = nil
    }

    /// Loads the next page of the subscriptions feed, appending to `videos`.
    /// No-ops when there is no continuation token or a page load is already in flight.
    func loadMore() async {
        guard YTTVAuthManager.shared.isSignedIn else { return }
        guard let token = nextPageToken, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let group = try await InnerTubeAPI.shared.fetchSubscriptions(continuationToken: token)
            nextPageToken = group.nextPageToken

            let (_, regular) = splitShorts(group.videos)
            let existingIds = Set(self.videos.map(\.id))
            let regularNew = regular
                .removingDuplicates()
                .filter { !existingIds.contains($0.id) }
            self.videos.append(contentsOf: regularNew)
        } catch {
            print("Error loading more subscriptions: \(error)")
        }
    }

    @MainActor
    func getMostRecentHistoryVideo() -> Video? {
        // Prefer the most recent regular video; fall back to the most recent
        // item (a Short) only when the loaded history page carries no regular
        // videos. `splitShorts` preserves order, so `.regular.first` is newest.
        let history = LibraryStore.shared.history
        return splitShorts(history).regular.first ?? history.first
    }

    private func splitShorts(_ all: [Video]) -> (shorts: [Video], regular: [Video]) {
        let shorts = all.filter { $0.isShort || ($0.duration.map { $0 > 0 && $0 <= 60 } ?? false) }
        let regular = all.filter { !$0.isShort && !($0.duration.map { $0 > 0 && $0 <= 60 } ?? false) }
        return (shorts, regular)
    }
}
