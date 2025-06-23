//
//  VideoPlayerViewModel.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 23/06/2025.
//

import Foundation
import Combine
import YouTubePlayerKit

/// ViewModel to handle YouTube player watch time tracking and resuming
// @MainActor
final class VideoPlayerViewModel: ObservableObject {
    @Published var hasResumed = false
    
    let youTubePlayer: YouTubePlayer
    
    private let watchTimeService = WatchTimeService.shared
    private var cancellables = Set<AnyCancellable>()
    private var saveTimer: Timer?
    
    private let video: Video
    
    // Throttle save operations to every 3 seconds to avoid excessive writes
    private let saveInterval: TimeInterval = 3.0
    
    init(video: Video, youTubePlayer: YouTubePlayer) {
        self.video = video
        self.youTubePlayer = youTubePlayer
        setupObservers()
    }
    
    deinit {
        saveTimer?.invalidate()
        cancellables.removeAll()
    }
    
    /// Resume video from last watched position if available
    func resumeIfNeeded() {
        guard !hasResumed else { return }
        
        let lastWatchTime = watchTimeService.getWatchTime(for: video.id)
        
        // Only resume if there's meaningful progress (more than 10 seconds)
        // and not near the end (leave 30 seconds at the end)
        guard lastWatchTime > 10.0 && lastWatchTime < (Double(video.duration) - 30) else {
            hasResumed = true
            return
        }
        
        Task {
            do {
                // Wait a bit for the player to be ready
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
                let measurement = Measurement(value: lastWatchTime, unit: UnitDuration.seconds)
                try await youTubePlayer.seek(to: measurement, allowSeekAhead: true)
                
                hasResumed = true
            } catch {
                print("Failed to resume video at \(lastWatchTime): \(error)")
                hasResumed = true
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Observe current time changes (throttled to avoid excessive calls)
        youTubePlayer.currentTimePublisher
            .throttle(for: .seconds(1), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] currentTime in
                self?.scheduleWatchTimeSave(currentTime.value)
            }
            .store(in: &cancellables)
        
        // Observe playback state to handle completion
        youTubePlayer.playbackStatePublisher
            .sink { [weak self] state in
                self?.handlePlaybackStateChange(state)
            }
            .store(in: &cancellables)
        
        // Save immediately when the player becomes ready and try to resume
        youTubePlayer.statePublisher
            .sink { [weak self] state in
                if state == .ready {
                    self?.resumeIfNeeded()
                }
            }
            .store(in: &cancellables)
    }
    
    private func scheduleWatchTimeSave(_ currentTime: TimeInterval) {
        // Invalidate existing timer
        saveTimer?.invalidate()
        
        // Schedule new save operation
        saveTimer = Timer.scheduledTimer(withTimeInterval: saveInterval, repeats: false) { [weak self] _ in
            self?.saveCurrentWatchTime(currentTime)
        }
    }
    
    private func saveCurrentWatchTime(_ currentTime: TimeInterval) {
        // Don't save if we're at the very beginning or very end
        let videoDuration = Double(video.duration)
        guard currentTime > 5.0 && currentTime < (videoDuration - 10.0) else {
            return
        }
        
        watchTimeService.setWatchTime(for: video.id, time: currentTime)
    }
    
    private func handlePlaybackStateChange(_ state: YouTubePlayer.PlaybackState) {
        switch state {
        case .ended:
            // Video completed - remove watch time since it's finished
            watchTimeService.removeWatchTime(for: video.id)
        default:
            break
        }
    }
}
