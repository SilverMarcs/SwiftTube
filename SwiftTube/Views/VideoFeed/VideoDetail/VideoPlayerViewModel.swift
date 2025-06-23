//
//  VideoPlayerViewModel.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 23/06/2025.
//

import Foundation
import Combine
import AVFoundation

/// ViewModel to handle AVPlayer watch time tracking and resuming
@MainActor
final class VideoPlayerViewModel: ObservableObject {
    @Published var hasResumed = false
    
    let player: AVPlayer
    
    private let watchTimeService = WatchTimeService.shared
    private var cancellables = Set<AnyCancellable>()
    private var saveTimer: Timer?
    private var timeObserver: Any?
    
    private let video: Video
    private let shouldResume: Bool
    
    // Throttle save operations to every 3 seconds to avoid excessive writes
    private let saveInterval: TimeInterval = 3.0
    
    init(video: Video, player: AVPlayer, shouldResume: Bool = true) {
        self.video = video
        self.player = player
        self.shouldResume = shouldResume
        setupObservers()
    }
    
    deinit {
        saveTimer?.invalidate()
        cancellables.removeAll()
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
        }
    }
    
    /// Resume video from last watched position if available
    func resumeIfNeeded() {
        guard !hasResumed && shouldResume else { 
            hasResumed = true
            return 
        }
        
        let lastWatchTime = watchTimeService.getWatchTime(for: video.id)
        
        // Only resume if there's meaningful progress (more than 10 seconds)
        // and not near the end (leave 30 seconds at the end)
        guard lastWatchTime > 10.0 && lastWatchTime < (Double(video.duration) - 30) else {
            hasResumed = true
            return
        }
        
        // Seek to the last watched position
        let seekTime = CMTime(seconds: lastWatchTime, preferredTimescale: 600)
        player.seek(to: seekTime) { [weak self] _ in
            self?.hasResumed = true
        }
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Observe current time changes (throttled to avoid excessive calls)
        let interval = CMTime(seconds: 1.0, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            let currentTime = time.seconds
            guard !currentTime.isNaN && !currentTime.isInfinite else { return }
            self?.scheduleWatchTimeSave(currentTime)
        }
        
        // Observe player item status changes
        player.publisher(for: \.currentItem?.status)
            .sink { [weak self] status in
                if status == .readyToPlay {
                    self?.resumeIfNeeded()
                }
            }
            .store(in: &cancellables)
        
        // Observe playback end
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
            .sink { [weak self] _ in
                self?.handlePlaybackEnd()
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
    
    private func handlePlaybackEnd() {
        // Video completed - remove watch time since it's finished
//        watchTimeService.removeWatchTime(for: video.id)
        
        // dont rmeove watchtime. instead TODO: start from beginning next time
    }
}
