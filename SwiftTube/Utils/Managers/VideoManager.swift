import SwiftUI

@Observable
class VideoManager {
    private(set) var player: YTPlayer?
    private(set) var isPlaying: Bool = false
    
    var isExpanded: Bool = false
    var currentVideo: Video? = nil {
        didSet {
            if !isSettingVideoWithoutAutoplay {
                handleVideoChange(from: oldValue, to: currentVideo, autoPlay: true)
            }
        }
    }
    var isMiniPlayerVisible: Bool = true
    #if os(macOS)
    var isMediaPlayerWindowOpen: Bool = false
    #endif
    
    private var timeUpdateTask: Task<Void, Never>?
    private let userDefaults = UserDefaultsManager.shared
    private var isSettingVideoWithoutAutoplay = false
    
    /// Set video without autoplay (useful for restoring from history)
    func setVideoWithoutAutoplay(_ video: Video) {
        isSettingVideoWithoutAutoplay = true
        defer { isSettingVideoWithoutAutoplay = false }
        
        let oldValue = currentVideo
        currentVideo = video
        handleVideoChange(from: oldValue, to: video, autoPlay: false)
    }
    
    /// Handle video change - automatically sets up player and loads video
    private func handleVideoChange(from oldVideo: Video?, to newVideo: Video?, autoPlay: Bool) {
        guard oldVideo?.id != newVideo?.id else { return }
        
        if let newVideo {
            // New video selected
            isPlaying = autoPlay
            #if !os(macOS)
            isExpanded = autoPlay // Auto-expand only if autoplaying (iOS only)
            #endif
            userDefaults.addToHistory(newVideo.id)
            createPlayerIfNeeded(autoPlay: autoPlay)
            loadVideo(newVideo)
        } else {
            // Video cleared (dismissed)
            timeUpdateTask?.cancel()
            Task {
                try? await player?.pause()
            }
        }
    }

    func dismiss() {
        isExpanded = false
        currentVideo = nil // This will trigger didSet and handle cleanup
    }
    
    @MainActor
    func togglePlayPause() async {
        guard let player else { return }
        
        do {
            if try await player.playbackState == .playing {
                isPlaying = false
                try? await player.pause()
            } else if try await player.playbackState == .paused {
                isPlaying = true
                try? await player.play()
            }
        } catch {
            // safer option maybe?
            isPlaying = true
            try? await player.play()
        }
    }
    
    private func createPlayerIfNeeded(autoPlay: Bool) {
        guard player == nil else { return }
        
        let config = YTPlayer.Configuration(autoPlay: autoPlay)
        let newPlayer = YTPlayer(configuration: config)
        player = newPlayer
        setupPlayerObserver()
    }
    
    private func loadVideo(_ video: Video) {
        guard let player else { return }
        
        // Load video with current progress directly
        let currentProgress = userDefaults.getWatchProgress(videoId: video.id)
        let startTime = currentProgress > 5 ? currentProgress : nil
            
        Task {
            try? await player.load(videoId: video.id, startTime: startTime)
            
            // Fetch and set duration if not already set
            if video.duration == nil, let duration = try? await player.duration {
                currentVideo?.duration = Int(duration)
            }
        }
    }
    
    private func setupPlayerObserver() {
        guard let player else { return }
        
        // Cancel existing task
        timeUpdateTask?.cancel()
        
        // Start observing player progress (every 10 seconds for progress saving, since high accuracy isn't needed)
        timeUpdateTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard let self = self else { break }
                
                // Get fresh current time directly from player
                if let currentTime = try? await player.currentPlaybackTime {
                    self.updateVideoProgress(currentTime)
                }
            }
        }
    }
    
    private func updateVideoProgress(_ seconds: TimeInterval) {
        guard let video = currentVideo else { return }
        video.updateWatchProgress(seconds)
    }
}
