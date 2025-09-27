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
}