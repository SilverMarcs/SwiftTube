import SwiftUI
import SwiftData

@Observable
class ShortsManager {
    var player: YTPlayer?
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
    
    private func createPlayerIfNeeded(id: String) {
        guard player == nil else { return }
        
        player = YTPlayer(configuration: .shorts)
    }
    
    private func loadVideo(_ video: Video) {
        guard let player else { return }
        
        Task {
            try? await player.load(videoId: video.id)
        }
    }
}
