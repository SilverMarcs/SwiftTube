import SwiftUI
import Combine
import SwiftData
import YouTubePlayerKit

@Observable
class ShortsManager {
    var player: YouTubePlayer?
    var currentVideo: Video?
    var currentIndex: Int = 0
    var watchStartTime: Date?
    
    /// Start playing a short video
    func startPlaying(_ video: Video, at index: Int) {
        guard currentVideo?.id != video.id else { return }
        
        currentVideo = video
        currentIndex = index
        watchStartTime = Date()
        
        createPlayerIfNeeded(id: video.id)
        loadVideo(video)
    }
    
    /// Switch to a different short video
    func switchTo(_ video: Video, at index: Int) {
        markCurrentVideoAsWatchedIfNeeded()
        currentVideo = video
        currentIndex = index
        watchStartTime = Date()
        loadVideo(video)
    }
    
    /// Check if a specific video is currently playing
    func isPlaying(_ video: Video) -> Bool {
        currentVideo?.id == video.id
    }
    
    func pause() async {
        guard let player else { return }
        try? await player.pause()
    }
    
    /// Mark current video as watched if we've been watching for about 90% of its duration
    func markCurrentVideoAsWatchedIfNeeded() {
        guard let video = currentVideo, let startTime = watchStartTime, let duration = video.duration else { return }
        
        let watchDuration = Date().timeIntervalSince(startTime)
        let ninetyPercentDuration = Double(duration) * 0.9
        
        if watchDuration >= ninetyPercentDuration {
            video.lastWatchedAt = Date()
        }
    }
    
    private func createPlayerIfNeeded(id: String) {
        guard player == nil else { return }
        
        player = YouTubePlayer(
            source: .video(id: id),
            parameters: .init(autoPlay: true, loopEnabled: true, showControls: false),
            configuration: .init(
                fullscreenMode: .system,
                allowsInlineMediaPlayback: true,
                allowsPictureInPictureMediaPlayback: false
            )
        )
    }
    
    private func loadVideo(_ video: Video) {
        guard let player else { return }
        
        Task {
            try? await player.load(source: .video(id: video.id))
            try? await player.play()
        }
    }
}
