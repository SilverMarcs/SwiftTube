//
//  CloudStoreManager.swift
//  Cathode
//
//  Originally a pure-iCloud KV store. Phase 2c: dual-mode storage where the
//  in-memory state is sourced from the user's YouTube account (via InnerTube)
//  while still being persisted to iCloud (under new `_yt` keys) so the data
//  survives offline launches and propagates across devices on the same
//  Apple ID.
//
//  Public API is intentionally unchanged so view callers don't change.
//
//  iCloud key namespace:
//   - savedChannels_yt       — fetched from /guide (subscribed channels)
//   - watchLaterVideos_yt    — fetched from playlist "WL"
//   - historyVideos_yt       — fetched from /browse FEhistory
//   - watchProgress_yt       — derived from history watchProgress + local pings
//
//  The original keys (savedChannels, watchLaterVideos, historyVideos,
//  watchProgress) are FROZEN — never read or written from new code so the
//  user can revert by rolling back.
//

import Foundation
import os

private let storeLog = Logger(subsystem: appSubsystem, category: "CloudStore")

@Observable
final class CloudStoreManager {
    static let shared = CloudStoreManager()

    /// Posted after `refreshFromYouTube()` completes (success or failure).
    static let didRefreshNotification = Notification.Name("CloudStoreManager.didRefresh")
    /// Posted by YTTVAuthManager (or callers) to request a refresh.
    static let signInChangedNotification = Notification.Name("CloudStoreManager.signInChanged")

    private let defaults = NSUbiquitousKeyValueStore.default

    private enum Keys {
        // YT-backed keys (Phase 2c).
        static let savedChannels  = "savedChannels_yt"
        static let bookmarkedVideos = "watchLaterVideos_yt"
        static let historyVideos  = "historyVideos_yt"
        static let watchProgress  = "watchProgress_yt"
    }

    private static let maxItems = 100

    // MARK: - Saved Channels

    private(set) var savedChannels: [Channel] = [] { didSet { persistChannels() } }

    // MARK: - Bookmarks (Watch Later)

    private(set) var bookmarkedVideos: [Video] = [] { didSet { persistBookmarks() } }

    // MARK: - History (most recent first, capped at maxItems)

    private(set) var historyVideos: [Video] = [] { didSet { persistHistory() } }

    // MARK: - Watch Progress

    private(set) var watchProgress: [String: Double] = [:] { didSet { persistProgress() } }

    // MARK: - In-flight refresh task

    private var refreshTask: Task<Void, Never>?

    private init() {
        load()
        setupCloudSync()
        setupSignInObserver()
    }

    // MARK: - iCloud Sync Setup

    private func setupCloudSync() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCloudStoreChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: defaults
        )
        defaults.synchronize()
    }

    private func setupSignInObserver() {
        NotificationCenter.default.addObserver(
            forName: Self.signInChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshFromYouTube()
            }
        }
    }

    @objc private func handleCloudStoreChange(_ notification: Notification) {
        Task { @MainActor in
            self.load()
        }
    }

    private func load() {
        let decoder = JSONDecoder()

        if let data = defaults.data(forKey: Keys.savedChannels),
           let decoded = try? decoder.decode([Channel].self, from: data) {
            savedChannels = decoded
        }

        if let data = defaults.data(forKey: Keys.bookmarkedVideos),
           let decoded = try? decoder.decode([Video].self, from: data) {
            bookmarkedVideos = decoded
        }

        if let data = defaults.data(forKey: Keys.historyVideos),
           let decoded = try? decoder.decode([Video].self, from: data) {
            historyVideos = decoded
        }

        if let data = defaults.data(forKey: Keys.watchProgress),
           let decoded = try? decoder.decode([String: Double].self, from: data) {
            watchProgress = decoded
        }
    }

    private func persistChannels() {
        let data = try? JSONEncoder().encode(savedChannels)
        defaults.set(data, forKey: Keys.savedChannels)
        defaults.synchronize()
    }

    private func persistBookmarks() {
        let data = try? JSONEncoder().encode(bookmarkedVideos)
        defaults.set(data, forKey: Keys.bookmarkedVideos)
        defaults.synchronize()
    }

    private func persistHistory() {
        let data = try? JSONEncoder().encode(historyVideos)
        defaults.set(data, forKey: Keys.historyVideos)
        defaults.synchronize()
    }

    private func persistProgress() {
        let data = try? JSONEncoder().encode(watchProgress)
        defaults.set(data, forKey: Keys.watchProgress)
        defaults.synchronize()
    }

    // MARK: - Channels
    //
    // Subscription management (subscribe/unsubscribe) is not yet exposed by
    // the InnerTube facade — SmartTube research listed it as a gap. For now
    // channel add/remove via the UI is local-only; the canonical list comes
    // from refreshFromYouTube() (fetchSubscribedChannels).
    // TODO: When InnerTubeAPI gains subscribe/unsubscribe, mirror those calls
    // here from addChannel/removeChannel.

    func addChannel(_ channel: Channel) {
        if !savedChannels.contains(where: { $0.id == channel.id }) {
            savedChannels.append(channel)
        }
    }

    func removeChannel(_ channel: Channel) {
        savedChannels.removeAll { $0.id == channel.id }
    }

    func updateChannel(_ channel: Channel) {
        if let index = savedChannels.firstIndex(where: { $0.id == channel.id }) {
            savedChannels[index] = channel
        }
    }

    // MARK: - Bookmarks (Watch Later)

    func isBookmarked(_ videoId: String) -> Bool {
        bookmarkedVideos.contains { $0.id == videoId }
    }

    func toggleBookmark(_ video: Video) {
        if let index = bookmarkedVideos.firstIndex(where: { $0.id == video.id }) {
            // Optimistic local removal.
            bookmarkedVideos.remove(at: index)
            let id = video.id
            Task {
                guard YTTVAuthManager.shared.isSignedIn else { return }
                do {
                    try await InnerTubeAPI.shared.removeFromWatchLater(videoId: id)
                } catch {
                    storeLog.error("removeFromWatchLater failed for \(id, privacy: .public) — rolling back: \(String(describing: error), privacy: .public)")
                    await MainActor.run { self.addBookmarkLocal(video) }
                }
            }
        } else {
            addBookmarkLocal(video)
            let id = video.id
            Task {
                guard YTTVAuthManager.shared.isSignedIn else { return }
                do {
                    try await InnerTubeAPI.shared.addToWatchLater(videoId: id)
                } catch {
                    storeLog.error("addToWatchLater failed for \(id, privacy: .public) — rolling back: \(String(describing: error), privacy: .public)")
                    await MainActor.run { self.bookmarkedVideos.removeAll { $0.id == id } }
                }
            }
        }
    }

    private func addBookmarkLocal(_ video: Video) {
        guard !bookmarkedVideos.contains(where: { $0.id == video.id }) else { return }
        bookmarkedVideos.append(video)
        if bookmarkedVideos.count > Self.maxItems {
            bookmarkedVideos.removeFirst()
        }
    }

    func removeBookmark(_ videoId: String) {
        guard let idx = bookmarkedVideos.firstIndex(where: { $0.id == videoId }) else { return }
        let removed = bookmarkedVideos.remove(at: idx)
        Task {
            guard YTTVAuthManager.shared.isSignedIn else { return }
            do {
                try await InnerTubeAPI.shared.removeFromWatchLater(videoId: videoId)
            } catch {
                storeLog.error("removeFromWatchLater failed for \(videoId, privacy: .public) — rolling back: \(String(describing: error), privacy: .public)")
                await MainActor.run { self.addBookmarkLocal(removed) }
            }
        }
    }

    // MARK: - History (most recent first)

    func isInHistory(_ videoId: String) -> Bool {
        historyVideos.contains { $0.id == videoId }
    }

    /// Inserts a video at the top of the local history list. The server-side
    /// recording is handled separately via watchtime pings from VideoManager
    /// (reportPlaybackStarted + reportWatchtime), so this method is local-only.
    func addToHistory(_ video: Video) {
        historyVideos.removeAll { $0.id == video.id }
        historyVideos.insert(video, at: 0)
        if historyVideos.count > Self.maxItems {
            historyVideos.removeLast()
        }
    }

    func removeFromHistory(_ videoId: String) {
        historyVideos.removeAll { $0.id == videoId }
    }

    func clearHistory() {
        historyVideos = []
    }

    // MARK: - Watch Progress
    //
    // Server-side progress is updated by watchtime pings (VideoManager).
    // Local state is what the UI reads; refreshFromYouTube() seeds it from
    // history watchProgress percentages on next launch.

    func getWatchProgress(videoId: String) -> Double {
        watchProgress[videoId] ?? 0
    }

    func setWatchProgress(videoId: String, progress: Double) {
        watchProgress[videoId] = progress
    }

    func clearWatchProgress(videoId: String) {
        watchProgress.removeValue(forKey: videoId)
    }

    // MARK: - YouTube refresh

    /// Pulls subscribed channels, Watch Later, and watch history from the
    /// authenticated YouTube account and replaces local state. No-op when
    /// not signed in. Safe to call repeatedly; concurrent refreshes coalesce.
    func refreshFromYouTube() {
        Task { @MainActor in
            guard YTTVAuthManager.shared.isSignedIn else {
                storeLog.notice("refreshFromYouTube: not signed in — skipping")
                return
            }
            if let existing = self.refreshTask, !existing.isCancelled {
                storeLog.notice("refreshFromYouTube: already running, coalescing")
                return
            }
            let task = Task {
                await self.performRefresh()
                await MainActor.run {
                    self.refreshTask = nil
                    NotificationCenter.default.post(name: Self.didRefreshNotification, object: nil)
                }
            }
            self.refreshTask = task
        }
    }

    private func performRefresh() async {
        storeLog.notice("refreshFromYouTube: starting")

        // Subscribed channels
        do {
            let itChannels = try await InnerTubeAPI.shared.fetchSubscribedChannels()
            let channels = itChannels.map { Channel($0) }
            // Replace wholesale: server is canonical.
            self.savedChannels = channels
            storeLog.notice("refreshFromYouTube: \(channels.count, privacy: .public) subscribed channels")
        } catch {
            storeLog.error("refreshFromYouTube: fetchSubscribedChannels failed: \(String(describing: error), privacy: .public)")
        }

        // Watch Later
        do {
            let group = try await InnerTubeAPI.shared.fetchPlaylistVideos(playlistId: "WL", continuationToken: nil)
            let videos = group.videos.map { Video($0) }
            self.bookmarkedVideos = videos
            storeLog.notice("refreshFromYouTube: \(videos.count, privacy: .public) watch-later videos")
        } catch {
            storeLog.error("refreshFromYouTube: fetchPlaylistVideos(WL) failed: \(String(describing: error), privacy: .public)")
        }

        // History (newest first, capped)
        do {
            let group = try await InnerTubeAPI.shared.fetchHistory(continuationToken: nil)
            let trimmed = Array(group.videos.prefix(Self.maxItems))
            self.historyVideos = trimmed.map { Video($0) }
            storeLog.notice("refreshFromYouTube: \(trimmed.count, privacy: .public) history videos")

            // Seed watch progress from server-provided percentages where
            // present. ITVideo.watchProgress is 0.0–1.0 (overlay percentage),
            // so multiply by duration to get a seconds value the UI expects.
            // Existing local entries are preserved when the server has no value.
            var progress = self.watchProgress
            for v in trimmed {
                guard let ratio = v.watchProgress, ratio > 0,
                      let durSecs = v.duration else { continue }
                let seconds = ratio * durSecs
                // Only write when we don't already have a newer (larger) value
                // — local pings during this session may be ahead of the
                // server-reported overlay percentage.
                let existing = progress[v.id] ?? 0
                if seconds > existing {
                    progress[v.id] = seconds
                }
            }
            self.watchProgress = progress
        } catch {
            storeLog.error("refreshFromYouTube: fetchHistory failed: \(String(describing: error), privacy: .public)")
        }

        storeLog.notice("refreshFromYouTube: done")
    }
}
