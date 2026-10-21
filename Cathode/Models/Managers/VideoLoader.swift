//
//  VideoLoader.swift
//  Cathode
//
//  Aggregates the user's subscriptions feed via InnerTube's `fetchSubscriptions()`
//  — a single authenticated call that returns newest-first videos with view
//  counts and durations already populated.
//

import SwiftUI

@MainActor
@Observable
final class VideoLoader {

    private(set) var videos: [Video] = []
    private(set) var shortVideos: [Video] = []
    private(set) var recommendations: [Video] = []
    private var recommendationPageToken: String?
    private var recommendationGeneration = UUID()
    private var isLoadingMoreRecommendations = false

    /// Re-entry guard for subscriptions pagination.
    private var isLoadingMore = false

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

    func loadRecommendationsIfNeeded() async {
        guard recommendations.isEmpty else { return }
        await loadRecommendations()
    }

    /// Publish the first page immediately; subsequent pages load as the user scrolls.
    func loadRecommendations() async {
        guard !isLoadingRecommendations else { return }
        isLoadingRecommendations = true
        recommendationGeneration = UUID()
        isLoadingMoreRecommendations = false
        defer { isLoadingRecommendations = false }
        do {
            let group = try await InnerTubeAPI.shared.fetchHome()
            try Task.checkCancellation()
            let (_, regular) = splitShorts(group.videos)
            recommendations = regular.removingDuplicates()
            recommendationPageToken = group.nextPageToken
            TopShelfCache.save(videos: recommendations)
        } catch {
            print("Error loading recommendations: \(error)")
        }
    }

    func loadMoreRecommendations() async {
        guard !isLoadingRecommendations, !isLoadingMoreRecommendations,
              let token = recommendationPageToken, !token.isEmpty else { return }
        let generation = recommendationGeneration
        isLoadingMoreRecommendations = true
        defer {
            if generation == recommendationGeneration { isLoadingMoreRecommendations = false }
        }
        do {
            let group = try await InnerTubeAPI.shared.fetchHome(continuationToken: token)
            try Task.checkCancellation()
            // A refresh replaces the feed; discard pages from the previous feed.
            guard generation == recommendationGeneration else { return }
            let (_, regular) = splitShorts(group.videos)
            recommendations = (recommendations + regular).removingDuplicates()
            recommendationPageToken = group.nextPageToken == token ? nil : group.nextPageToken
        } catch {
            print("Error loading more recommendations: \(error)")
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
