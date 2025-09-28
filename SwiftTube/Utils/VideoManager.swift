import SwiftUI
import YouTubePlayerKit

@Observable
class VideoManager {
    var currentVideo: Video? {
        didSet {
            updatePlayer()
        }
    }
    var isExpanded: Bool = false
    var youTubePlayer: YouTubePlayer?
    var isPlaying: Bool = true // Assume playing since autoplay is true
    
    // Temporarily store current video when entering Shorts view
    private var temporaryStoredVideo: Video?
    
    private func updatePlayer() {
        if let video = currentVideo {
            youTubePlayer = YouTubePlayer(
                source: .video(id: video.id),
                parameters: .init(
                    autoPlay: true,
                    showControls: true
                ),
                configuration: .init(
                    fullscreenMode: .system,
                    allowsInlineMediaPlayback: true,
                    allowsPictureInPictureMediaPlayback: true
                )
            )
        } else {
            youTubePlayer = nil
        }
    }
    
    func play() async {
        do {
            try await youTubePlayer?.play()
            isPlaying = true
        } catch {
            print("Failed to play: \(error)")
        }
    }
    
    func pause() async {
        do {
            try await youTubePlayer?.pause()
            isPlaying = false
        } catch {
            print("Failed to pause: \(error)")
        }
    }
    
    func togglePlayPause() async {
        if isPlaying {
            await pause()
        } else {
            await play()
        }
    }
    
    /// Temporarily stores the current video and sets currentVideo to nil
    func temporarilyStoreCurrentVideo() {
        temporaryStoredVideo = currentVideo
        currentVideo = nil
    }
    
    /// Restores the temporarily stored video if there was one
    func restoreStoredVideo() {
        if let stored = temporaryStoredVideo {
            currentVideo = stored
            temporaryStoredVideo = nil
        }
    }
}
