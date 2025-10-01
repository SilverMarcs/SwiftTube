import SwiftUI
import SwiftData

@Observable
class VideoManager {
    var player: YTPlayer?
    private(set) var isPlaying: Bool = false
    
    var isExpanded: Bool = false
    var currentVideo: Video? = nil
    var isMiniPlayerVisible: Bool = true
    
    private var timeUpdateTask: Task<Void, Never>?
    
    /// Start playing a video
    func startPlaying(_ video: Video) {
        guard currentVideo?.id != video.id else { return }
        isPlaying = true

        // Update to new video
        currentVideo = video
        video.lastWatchedAt = Date()
        isExpanded = true
        
        // Create player if needed and load video
        createPlayerIfNeeded(id: video.id)
        loadVideo(video)
    }
    
    /// Check if a specific video is currently playing
    func isPlaying(_ video: Video) -> Bool {
        currentVideo?.id == video.id
    }
    
    /// Play a video or expand the player if it's already playing
    func playOrExpand(_ video: Video) {
        if isPlaying(video) {
            isExpanded = true
        } else {
            startPlaying(video)
        }
    }

    func dismiss() {
        currentVideo = nil
        isExpanded = false
        Task {
            try? await player?.pause()
        }
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
    
    private func createPlayerIfNeeded(id: String) {
        guard player == nil else { return }
        
        let newPlayer = YTPlayer()
        player = newPlayer
        setupPlayerObserver()
    }
    
    private func loadVideo(_ video: Video) {
        guard let player else { return }
        
        // Load video with current progress directly
        let startTime = video.watchProgressSeconds > 5 ? video.watchProgressSeconds : nil
            
        Task {
            try? await player.load(videoId: video.id, startTime: startTime)
            // Auto-play is handled by the player configuration
        }
    }
    
    /// Retry loading the current video
    func retryCurrentVideo() {
        guard let video = currentVideo else { return }
        loadVideo(video)
    }
    
    private func setupPlayerObserver() {
        guard let player else { return }
        
        // Cancel existing task
        timeUpdateTask?.cancel()
        
        // Start observing player progress (every 5 seconds for progress saving)
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
