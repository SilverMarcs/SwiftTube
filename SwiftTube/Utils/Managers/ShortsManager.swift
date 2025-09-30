import SwiftUI
import Combine
import SwiftData
import YouTubePlayerKit

@Observable
class ShortsManager {
    var player: YouTubePlayer?
    var currentVideo: Video?
    var currentIndex: Int = 0
    
    /// Start playing a short video
    func startPlaying(_ video: Video, at index: Int) {
        guard currentVideo?.id != video.id else { return }
        
        currentVideo = video
        currentIndex = index
        
        createPlayerIfNeeded(id: video.id)
        loadVideo(video)
    }
    
    /// Switch to a different short video
    func switchTo(_ video: Video, at index: Int) {
        if let currentVideo {
            currentVideo.lastWatchedAt = Date()
        }
        currentVideo = video
        currentIndex = index
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
    
    /// Mark current video as watched
    func markCurrentVideoAsWatchedIfNeeded() {
        guard let video = currentVideo else { return }
        video.lastWatchedAt = Date()
    }
    
    private func createPlayerIfNeeded(id: String) {
        guard player == nil else { return }
        
        player = YouTubePlayer(
            source: .video(id: id),
            parameters: .init(autoPlay: true, loopEnabled: true, showControls: false),
            configuration: .init(allowsInlineMediaPlayback: true)
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
