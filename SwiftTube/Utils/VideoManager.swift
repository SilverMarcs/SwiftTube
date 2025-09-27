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
                    allowsInlineMediaPlayback: true
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
}