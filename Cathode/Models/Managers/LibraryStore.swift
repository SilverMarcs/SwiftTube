//
//  LibraryStore.swift
//  Cathode
//
//  Single source of truth for subscribed channels, Watch Later, history, and
//  resume positions.
//
//  Storage split:
//   - Subscribed channels + Watch Later — YouTube-backed (always fetched fresh
//     from InnerTube on launch; no local persistence)
//   - History + resume positions        — iCloud KV (YouTube exposes no write
//     API for these, so we own them across Apple devices)
//

import Foundation
import os
import SwiftUI

private let libraryLog = Logger(subsystem: appSubsystem, category: "LibraryStore")

@MainActor
@Observable
final class LibraryStore {
    static let shared = LibraryStore()

    /// Posted by YTTVAuthManager when sign-in completes.
    static let signInChangedNotification = Notification.Name("LibraryStore.signInChanged")

    private(set) var subscribedChannels: [Channel] = []
    private(set) var watchLater: [Video] = []
    private(set) var history: [Video] = [] { didSet { persistHistory() } }

    /// Channel metadata indexed by channelId. Hydrated from `subscribedChannels`
    /// on every refresh, and extended on demand when views resolve a channel
    /// the user isn't subscribed to (e.g. tapping into a creator from search).
    private(set) var channelsById: [String: Channel] = [:]

    private var watchLaterNextPageToken: String?
    private var isLoadingMoreWatchLater = false

    /// Resume positions in seconds, keyed by videoId. iCloud-synced across Apple devices.
    private(set) var resumePositions: [String: Double] = [:]

    private let ubiquitous = NSUbiquitousKeyValueStore.default

    private enum Keys {
        static let resumePositions = "resumePositions_yt"
        static let history         = "historyVideos_yt"
    }

    private static let historyLimit = 100

    private var refreshTask: Task<Void, Never>?

    private init() {
        loadFromCloud()
        setupCloudObserver()
    }

    // MARK: - iCloud KV (history + resume positions)

    private func loadFromCloud() {
        ubiquitous.synchronize()
        if let data = ubiquitous.data(forKey: Keys.resumePositions),
           let decoded = try? JSONDecoder().decode([String: Double].self, from: data) {
            resumePositions = decoded
        }
        if let data = ubiquitous.data(forKey: Keys.history),
           let decoded = try? JSONDecoder().decode([Video].self, from: data) {
            history = decoded
        }
    }

    private func persistResumePositions() {
        let data = try? JSONEncoder().encode(resumePositions)
        ubiquitous.set(data, forKey: Keys.resumePositions)
        ubiquitous.synchronize()
    }

    private func persistHistory() {
        let data = try? JSONEncoder().encode(history)
        ubiquitous.set(data, forKey: Keys.history)
        ubiquitous.synchronize()
    }

    private func setupCloudObserver() {
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: ubiquitous,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.loadFromCloud() }
        }
    }

    // MARK: - Refresh (subscriptions + watch later)

    /// Pulls subscribed channels and Watch Later from YouTube.
    /// Coalesces concurrent calls. No-op when not signed in.
    /// History and resume positions are iCloud-backed and aren't touched here.
    func refresh() async {
        guard YTTVAuthManager.shared.isSignedIn else {
            libraryLog.notice("refresh: not signed in — skipping")
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
        libraryLog.notice("refresh: starting")

        do {
            let channels = try await InnerTubeAPI.shared.fetchSubscribedChannels()
            self.subscribedChannels = channels
            for ch in channels { self.channelsById[ch.id] = ch }
            libraryLog.notice("refresh: \(channels.count, privacy: .public) subscribed channels")
        } catch {
            libraryLog.error("refresh: fetchSubscribedChannels failed: \(String(describing: error), privacy: .public)")
        }

        do {
            let group = try await InnerTubeAPI.shared.fetchPlaylistVideos(playlistId: "WL", continuationToken: nil)
            self.watchLater = group.videos
            self.watchLaterNextPageToken = group.nextPageToken
            libraryLog.notice("refresh: \(group.videos.count, privacy: .public) watch-later videos")
        } catch {
            libraryLog.error("refresh: fetchPlaylistVideos(WL) failed: \(String(describing: error), privacy: .public)")
        }

        libraryLog.notice("refresh: done")
    }

    // MARK: - Channel cache

    func channel(forId id: String) -> Channel? {
        // Feed video tiles often reference a channel by @handle rather than its
        // UC… id, so also match handles.
        if let direct = channelsById[id] { return direct }
        if id.hasPrefix("@") {
            return subscribedChannels.first { $0.handle == id }
        }
        return nil
    }

    func remember(_ channel: Channel) {
        channelsById[channel.id] = channel
    }

    // MARK: - Pagination (Watch Later only)

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
                    libraryLog.error("removeFromWatchLater failed for \(id, privacy: .public): \(String(describing: error), privacy: .public)")
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
                    libraryLog.error("addToWatchLater failed for \(id, privacy: .public): \(String(describing: error), privacy: .public)")
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
                libraryLog.error("removeFromWatchLater failed for \(videoId, privacy: .public): \(String(describing: error), privacy: .public)")
                await MainActor.run { self.insertBookmarkLocal(removed) }
            }
        }
    }

    // MARK: - History (iCloud-backed)

    func isInHistory(_ videoId: String) -> Bool {
        history.contains { $0.id == videoId }
    }

    /// Inserts the video at the top of history (most-recent-first). If it was already
    /// present, it is moved to the top. Capped at `historyLimit` entries.
    func addToHistory(_ video: Video) {
        history.removeAll { $0.id == video.id }
        history.insert(video, at: 0)
        if history.count > Self.historyLimit {
            history.removeLast(history.count - Self.historyLimit)
        }
    }

    func removeFromHistory(_ videoId: String) {
        history.removeAll { $0.id == videoId }
    }

    func clearHistory() {
        history = []
    }

    // MARK: - Resume positions

    func setResumePosition(videoId: String, seconds: Double) {
        let sanitized = max(0, seconds)
        // Avoid overwriting a positive saved progress with 0 (some players
        // report currentTime as 0 on item end / transitions).
        let previous = resumePositions[videoId] ?? 0
        if sanitized == 0 && previous > 0 { return }
        resumePositions[videoId] = sanitized
        persistResumePositions()
    }

    /// Resume position in seconds for the given video.
    /// Prefers our iCloud cache; falls back to YouTube's server-reported
    /// `watchProgress` (0.0–1.0 × duration) so progress made on youtube.com
    /// flows into the app on first open. The next play in the app writes
    /// to iCloud and takes over from there.
    func resumeSeconds(for video: Video) -> Double? {
        if let local = resumePositions[video.id], local > 0 { return local }
        guard let ratio = video.watchProgress, ratio > 0,
              let duration = video.duration, duration > 0 else { return nil }
        return ratio * duration
    }

    func clearResumePosition(videoId: String) {
        resumePositions.removeValue(forKey: videoId)
        persistResumePositions()
    }
}
