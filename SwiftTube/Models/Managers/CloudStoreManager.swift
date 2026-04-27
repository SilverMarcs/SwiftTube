//
//  UserDefaultsManager.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 03/10/2025.
//

import Foundation

@Observable
final class CloudStoreManager {
    static let shared = CloudStoreManager()

    private let defaults = NSUbiquitousKeyValueStore.default

    private enum Keys {
        static let savedChannels = "savedChannels"
        static let watchLaterVideos = "watchLaterVideos"
        static let historyVideos = "historyVideos"
        static let watchProgress = "watchProgress"
    }

    private static let maxItems = 50

    // MARK: - Saved Channels

    private(set) var savedChannels: [Channel] = [] { didSet { persistChannels() } }

    // MARK: - Watch Later (ordered, capped at 50, full Video objects)

    private(set) var watchLaterVideos: [Video] = [] { didSet { persistWatchLater() } }

    // MARK: - History (most recent first, capped at 50, full Video objects)

    private(set) var historyVideos: [Video] = [] { didSet { persistHistory() } }

    // MARK: - Watch Progress

    private(set) var watchProgress: [String: Double] = [:] { didSet { persistProgress() } }

    private init() {
        load()
        setupCloudSync()
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

        if let data = defaults.data(forKey: Keys.watchLaterVideos),
           let decoded = try? decoder.decode([Video].self, from: data) {
            watchLaterVideos = decoded
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

    private func persistWatchLater() {
        let data = try? JSONEncoder().encode(watchLaterVideos)
        defaults.set(data, forKey: Keys.watchLaterVideos)
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

    // MARK: - Watch Later

    func isWatchLater(_ videoId: String) -> Bool {
        watchLaterVideos.contains { $0.id == videoId }
    }

    func toggleWatchLater(_ video: Video) {
        if let index = watchLaterVideos.firstIndex(where: { $0.id == video.id }) {
            watchLaterVideos.remove(at: index)
        } else {
            watchLaterVideos.append(video)
            if watchLaterVideos.count > Self.maxItems {
                watchLaterVideos.removeFirst()
            }
        }
    }

    func removeFromWatchLater(_ videoId: String) {
        watchLaterVideos.removeAll { $0.id == videoId }
    }

    // MARK: - History (most recent first)

    func isInHistory(_ videoId: String) -> Bool {
        historyVideos.contains { $0.id == videoId }
    }

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

    func getWatchProgress(videoId: String) -> Double {
        watchProgress[videoId] ?? 0
    }

    func setWatchProgress(videoId: String, progress: Double) {
        watchProgress[videoId] = progress
    }

    func clearWatchProgress(videoId: String) {
        watchProgress.removeValue(forKey: videoId)
    }
}
