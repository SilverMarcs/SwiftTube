//
//  Video+WatchTime.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 23/06/2025.
//

import Foundation

extension Video {
    /// Get the watch progress percentage (0.0 to 1.0) for this video
    var watchProgress: Double {
        WatchTimeService.shared.getWatchProgress(for: id, totalDuration: Double(duration))
    }
    
    /// Get the last watched position in seconds for this video
    var watchTime: TimeInterval {
        WatchTimeService.shared.getWatchTime(for: id)
    }
    
    /// Check if this video has been partially watched
    var hasWatchProgress: Bool {
        WatchTimeService.shared.hasWatchTime(for: id)
    }
    
    /// Check if this video has been mostly completed (watched more than 90%)
    var isWatched: Bool {
        watchProgress > 0.9
    }
    
    /// Get a formatted string showing watch progress
    var watchProgressText: String? {
        guard hasWatchProgress else { return nil }
        
        let currentTime = watchTime
        let totalTime = Double(duration)
        
        let currentMinutes = Int(currentTime) / 60
        let currentSeconds = Int(currentTime) % 60
        let totalMinutes = Int(totalTime) / 60
        let totalSecondsRemaining = Int(totalTime) % 60
        
        return String(format: "%d:%02d / %d:%02d", currentMinutes, currentSeconds, totalMinutes, totalSecondsRemaining)
    }
}
