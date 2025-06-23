//
//  WatchTimeService.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 23/06/2025.
//

import Foundation
import Combine

/// Service to persist and retrieve video watch time across app launches
// @MainActor
final class WatchTimeService: ObservableObject {
    static let shared = WatchTimeService()
    
    private let userDefaults = UserDefaults.standard
    private let watchTimeKey = "swifttube_watch_times"
    
    private init() {}
    
    /// Get the last watched position for a video
    func getWatchTime(for videoId: String) -> TimeInterval {
        let watchTimes = getAllWatchTimes()
        return watchTimes[videoId] ?? 0.0
    }
    
    /// Set the watch time for a video
    func setWatchTime(for videoId: String, time: TimeInterval) {
        // Only save if more than 5 seconds to avoid saving at the very beginning
        guard time > 5.0 else { return }
        
        var watchTimes = getAllWatchTimes()
        watchTimes[videoId] = time
        
        userDefaults.set(watchTimes, forKey: watchTimeKey)
    }
    
    /// Remove watch time for a video (when video is completed)
    func removeWatchTime(for videoId: String) {
        var watchTimes = getAllWatchTimes()
        watchTimes.removeValue(forKey: videoId)
        
        userDefaults.set(watchTimes, forKey: watchTimeKey)
    }
    
    /// Check if a video has been watched (has saved progress)
    func hasWatchTime(for videoId: String) -> Bool {
        let watchTime = getWatchTime(for: videoId)
        return watchTime > 5.0 // Consider watched if more than 5 seconds
    }
    
    /// Get progress percentage (0.0 to 1.0) for a video
    func getWatchProgress(for videoId: String, totalDuration: TimeInterval) -> Double {
        guard totalDuration > 0 else { return 0.0 }
        let watchTime = getWatchTime(for: videoId)
        return min(watchTime / totalDuration, 1.0)
    }
    
    /// Clear all watch times (useful for settings/privacy)
    func clearAllWatchTimes() {
        userDefaults.removeObject(forKey: watchTimeKey)
    }
    
    // MARK: - Private Methods
    
    private func getAllWatchTimes() -> [String: TimeInterval] {
        return userDefaults.object(forKey: watchTimeKey) as? [String: TimeInterval] ?? [:]
    }
}
