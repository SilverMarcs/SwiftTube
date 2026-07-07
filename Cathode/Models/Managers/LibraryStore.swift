//
//  LibraryStore.swift
//  Cathode
//
//  Single source of truth for subscribed channels, Watch Later, and history.
//  Everything is YouTube-backed via TV OAuth:
//   - Subscribed channels + Watch Later — InnerTube TV client
//   - History                            — InnerTube TV client (FEhistory browse)
//   - Watch progress                     — `Video.watchProgress` in feed/history
//                                          responses; updated server-side by the
//                                          watchtime pings VideoManager fires
//                                          (which use cookie auth for SAPISIDHASH).
//
//  No local persistence. Legacy iCloud KV keys (`resumePositions_yt`,
//  `historyVideos_yt`) are left untouched so a downgrade can still read them.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class LibraryStore {
    static let shared = LibraryStore()

    /// Posted by YTTVAuthManager when sign-in completes.
    static let signInChangedNotification = Notification.Name("LibraryStore.signInChanged")

    private(set) var subscribedChannels: [Channel] = []
    private(set) var watchLater: [Video] = []
    private(set) var history: [Video] = []

    /// Channel metadata indexed by channelId. Hydrated from `subscribedChannels`
    /// on every refresh, and extended on demand when views resolve a channel
    /// the user isn't subscribed to (e.g. tapping into a creator from search).
    private(set) var channelsById: [String: Channel] = [:]

    private var watchLaterNextPageToken: String?
    private var historyNextPageToken: String?
    private var isLoadingMoreWatchLater = false
    private var isLoadingMoreHistory = false

    private var refreshTask: Task<Void, Never>?

    private init() {}

    // MARK: - Refresh

    /// Pulls subscribed channels, Watch Later, and history from YouTube.
    /// Coalesces concurrent calls. No-op when not signed in (TV OAuth).
    /// History additionally requires cookie auth — silently skipped otherwise.
    func refresh() async {
        guard YTTVAuthManager.shared.isSignedIn else {
            return
        }
        if let existing = refreshTask, !existing.isCancelled {
            await existing.value
            return
        }
        let task = Task { await self.performRefresh() }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    private func performRefresh() async {

        do {
            let channels = try await InnerTubeAPI.shared.fetchSubscribedChannels()
            self.subscribedChannels = channels
            for ch in channels { self.channelsById[ch.id] = ch }
        } catch {
        }

        do {
            let group = try await InnerTubeAPI.shared.fetchPlaylistVideos(playlistId: "WL", continuationToken: nil)
            self.watchLater = group.videos
            self.watchLaterNextPageToken = group.nextPageToken
        } catch {
        }

        do {
            let group = try await InnerTubeAPI.shared.fetchHistory(continuationToken: nil)
            self.history = group.videos
            self.historyNextPageToken = group.nextPageToken
        } catch {
        }

    }

    // MARK: - Channel cache

    func channel(forId id: String) -> Channel? {
        if let direct = channelsById[id] { return direct }
        if id.hasPrefix("@") {
            return subscribedChannels.first { $0.handle == id }
        }
        return nil
    }

    func remember(_ channel: Channel) {
        channelsById[channel.id] = channel
    }

    // MARK: - Pagination

    func loadMoreWatchLater() async {
        guard let token = watchLaterNextPageToken, !isLoadingMoreWatchLater else { return }
        isLoadingMoreWatchLater = true
        defer { isLoadingMoreWatchLater = false }
        do {
            let group = try await InnerTubeAPI.shared.fetchPlaylistVideos(playlistId: "WL", continuationToken: token)
            let existing = Set(watchLater.map(\.id))
            watchLater.append(contentsOf: group.videos.filter { !existing.contains($0.id) })
            watchLaterNextPageToken = group.nextPageToken
        } catch {
            print("loadMoreWatchLater: \(error)")
        }
    }

    /// Whether the history stream has another page to fetch.
    var canLoadMoreHistory: Bool { historyNextPageToken != nil }

    func loadMoreHistory() async {
        guard let token = historyNextPageToken, !isLoadingMoreHistory else { return }
        isLoadingMoreHistory = true
        defer { isLoadingMoreHistory = false }
        do {
            let group = try await InnerTubeAPI.shared.fetchHistory(continuationToken: token)
            let existing = Set(history.map(\.id))
            history.append(contentsOf: group.videos.filter { !existing.contains($0.id) })
            historyNextPageToken = group.nextPageToken
        } catch {
            print("loadMoreHistory: \(error)")
        }
    }

    // MARK: - Subscriptions

    /// Resilient subscription check — `channelId` may be either the canonical
    /// `UC…` form or a `@handle`, depending on where the caller got it (video
    /// tiles sometimes only carry the handle).
    func isSubscribed(channelId: String) -> Bool {
        if subscribedChannels.contains(where: { $0.id == channelId }) { return true }
        if channelId.hasPrefix("@") {
            return subscribedChannels.contains { $0.handle == channelId }
        }
        return false
    }

    /// Toggles subscription state for a channel. Optimistic local update; rolls
    /// back if the server call fails. YouTube's FEchannels list lags about
    /// 5-10s after subscribe/unsubscribe, so we manage local state directly
    /// rather than re-fetching immediately.
    func toggleSubscription(_ channel: Channel) {
        let id = channel.id
        if let index = subscribedChannels.firstIndex(where: { $0.id == id }) {
            let removed = subscribedChannels.remove(at: index)
            Task {
                guard YTTVAuthManager.shared.isSignedIn else { return }
                do {
                    try await InnerTubeAPI.shared.unsubscribe(channelId: id)
                } catch {
                    await MainActor.run { self.insertSubscriptionLocal(removed) }
                }
            }
        } else {
            insertSubscriptionLocal(channel)
            Task {
                guard YTTVAuthManager.shared.isSignedIn else { return }
                do {
                    try await InnerTubeAPI.shared.subscribe(channelId: id)
                } catch {
                    await MainActor.run {
                        self.subscribedChannels.removeAll { $0.id == id }
                    }
                }
            }
        }
    }

    private func insertSubscriptionLocal(_ channel: Channel) {
        guard !subscribedChannels.contains(where: { $0.id == channel.id }) else { return }
        // Keep alphabetical ordering to match `parseChannelsTab`'s sort.
        let insertIndex = subscribedChannels.firstIndex { existing in
            existing.title.localizedCaseInsensitiveCompare(channel.title) == .orderedDescending
        } ?? subscribedChannels.endIndex
        subscribedChannels.insert(channel, at: insertIndex)
        channelsById[channel.id] = channel
    }

    // MARK: - Bookmarks (Watch Later)

    func isBookmarked(_ videoId: String) -> Bool {
        watchLater.contains { $0.id == videoId }
    }

    /// Toggles Watch Later membership. Optimistic local update; rolls back if
    /// the server call fails.
    func toggleBookmark(_ video: Video) {
        let id = video.id
        if let index = watchLater.firstIndex(where: { $0.id == id }) {
            let removed = watchLater.remove(at: index)
            Task {
                guard YTTVAuthManager.shared.isSignedIn else { return }
                do {
                    try await InnerTubeAPI.shared.removeFromWatchLater(videoId: id)
                } catch {
                    await MainActor.run { self.insertBookmarkLocal(removed) }
                }
            }
        } else {
            insertBookmarkLocal(video)
            Task {
                guard YTTVAuthManager.shared.isSignedIn else { return }
                do {
                    try await InnerTubeAPI.shared.addToWatchLater(videoId: id)
                } catch {
                    await MainActor.run {
                        self.watchLater.removeAll { $0.id == id }
                    }
                }
            }
        }
    }

    private func insertBookmarkLocal(_ video: Video) {
        guard !watchLater.contains(where: { $0.id == video.id }) else { return }
        watchLater.insert(video, at: 0)
    }

    func removeBookmark(_ videoId: String) {
        guard let idx = watchLater.firstIndex(where: { $0.id == videoId }) else { return }
        let removed = watchLater.remove(at: idx)
        Task {
            guard YTTVAuthManager.shared.isSignedIn else { return }
            do {
                try await InnerTubeAPI.shared.removeFromWatchLater(videoId: videoId)
            } catch {
                await MainActor.run { self.insertBookmarkLocal(removed) }
            }
        }
    }

    // MARK: - Resume positions
    //
    // Resume comes from YouTube's `watchProgress` field in feed/history rows,
    // populated server-side by the watchtime pings VideoManager fires. No
    // local cache.

    func resumeSeconds(for video: Video) -> Double? {
        guard let ratio = video.watchProgress, ratio > 0,
              let duration = video.duration, duration > 0 else { return nil }
        return ratio * duration
    }
}
