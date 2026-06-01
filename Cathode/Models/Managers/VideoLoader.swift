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

    var mode: FeedMode = YTTVAuthManager.shared.isSignedIn ? .subscriptions : .recommendations

    /// Re-entry guard for `loadMore()`.
    private var isLoadingMore: Bool = false

    /// Continuation token for the next page of the InnerTube subscriptions feed.
    /// `nil` once the end of the feed has been reached or before the first load.
    private(set) var nextPageToken: String?

    /// In-memory order for shorts (video IDs). Shuffled on first feed load of the
    /// process; subsequent reloads preserve this order so prefetched stream URLs
    /// stay aligned with what the user actually swipes through.
    private var shortsOrder: [String] = []

    var currentVideos: [Video] {
        switch mode {
        case .subscriptions:  return videos
        case .recommendations: return recommendations
        }
    }

    /// Reloads the subscriptions feed from scratch.
    func loadAllChannelVideos() async {
        guard YTTVAuthManager.shared.isSignedIn else { return }
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

    func refreshCurrent() async {
        switch mode {
        case .subscriptions:   await loadAllChannelVideos()
        case .recommendations: await loadRecommendations()
        }
    }

    func switchTo(_ target: FeedMode) async {
        mode = target
        if target == .recommendations && recommendations.isEmpty {
            await loadRecommendations()
        }
    }

    func loadRecommendations() async {
        do {
            let recs = try await InnerTubeAPI.shared.fetchAllRecommendations()
            let (_, regular) = splitShorts(recs)
            let shuffled = regular.shuffled()
            let deduped = shuffled.removingDuplicates()
            withAnimation {
                self.recommendations = deduped
            }
            TopShelfCache.save(videos: deduped)
        } catch {
            print("Error loading recommendations: \(error)")
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
