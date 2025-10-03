//
//  UserDefaultsManager.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 03/10/2025.
//

import Foundation

// TODO: does this need to be .shared

@Observable
final class UserDefaultsManager {
    static let shared = UserDefaultsManager()
    
    private let defaults = UserDefaults.standard
    
    // Keys
    private enum Keys {
        static let savedChannels = "savedChannels"
        static let watchLaterIds = "watchLaterIds"
        static let historyIds = "historyIds"
        static let watchProgress = "watchProgress"
    }
    
    // MARK: - Saved Channels
    
    private(set) var savedChannels: [Channel] = [] { didSet { persistChannels() } }
    
    // MARK: - Watch Later
    
    private(set) var watchLaterIds: Set<String> = [] { didSet { persistWatchLater() } }
    
    // MARK: - History
    
    private(set) var historyIds: Set<String> = [] { didSet { persistHistory() } }
    
    // MARK: - Watch Progress
    
    private(set) var watchProgress: [String: Double] = [:] { didSet { persistProgress() } }
    
    private init() {
        load()
    }
    
    private func load() {
        let decoder = JSONDecoder()
        
        if let data = defaults.data(forKey: Keys.savedChannels),
           let decoded = try? decoder.decode([Channel].self, from: data) {
            savedChannels = decoded
        }
        
        if let data = defaults.data(forKey: Keys.watchLaterIds),
           let decoded = try? decoder.decode(Set<String>.self, from: data) {
            watchLaterIds = decoded
        }
        
        if let data = defaults.data(forKey: Keys.historyIds),
           let decoded = try? decoder.decode(Set<String>.self, from: data) {
            historyIds = decoded
        }
        
        if let data = defaults.data(forKey: Keys.watchProgress),
           let decoded = try? decoder.decode([String: Double].self, from: data) {
            watchProgress = decoded
        }
    }
    
    private func persistChannels() {
        let data = try? JSONEncoder().encode(savedChannels)
        defaults.set(data, forKey: Keys.savedChannels)
    }
    
    private func persistWatchLater() {
        let data = try? JSONEncoder().encode(watchLaterIds)
        defaults.set(data, forKey: Keys.watchLaterIds)
    }
    
    private func persistHistory() {
        let data = try? JSONEncoder().encode(historyIds)
        defaults.set(data, forKey: Keys.historyIds)
    }
    
    private func persistProgress() {
        let data = try? JSONEncoder().encode(watchProgress)
        defaults.set(data, forKey: Keys.watchProgress)
    }
    
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
    
    // MARK: - Watch Later (using Set for O(1) lookups)
    
    func isWatchLater(_ videoId: String) -> Bool {
        watchLaterIds.contains(videoId)
    }
    
    func toggleWatchLater(_ videoId: String) {
        if watchLaterIds.contains(videoId) {
            watchLaterIds.remove(videoId)
        } else {
            watchLaterIds.insert(videoId)
        }
    }
    
    func addToWatchLater(_ videoId: String) {
        watchLaterIds.insert(videoId)
    }
    
    func removeFromWatchLater(_ videoId: String) {
        watchLaterIds.remove(videoId)
    }
    
    // MARK: - History (using Set for O(1) lookups)
    
    func isInHistory(_ videoId: String) -> Bool {
        historyIds.contains(videoId)
    }
    
    func addToHistory(_ videoId: String) {
        historyIds.insert(videoId)
    }
    
    func removeFromHistory(_ videoId: String) {
        historyIds.remove(videoId)
    }
    
    func clearHistory() {
        historyIds = []
    }
    
    // MARK: - Watch Progress (Dictionary for O(1) lookups)
    
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
