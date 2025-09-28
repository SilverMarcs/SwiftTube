import SwiftUI
import YouTubePlayerKit

@Observable
class VideoManager {
    var currentVideo: Video?
    var isExpanded: Bool = false
    var isPlaying: Bool = true // Assume playing since autoplay is true
    
    // Computed property that automatically creates player when video is available
    var youTubePlayer: YouTubePlayer? {
        guard let video = currentVideo else { return nil }
        
        return YouTubePlayer(
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
    }
    
    // Temporarily store current video when entering Shorts view
    private var temporaryStoredVideo: Video?
    
    func play() async {
        guard let player = youTubePlayer else { return }
        
        do {
            try await player.play()
            isPlaying = true
        } catch {
            print("Failed to play: \(error)")
        }
    }
    
    func pause() async {
        guard let player = youTubePlayer else { return }
        
        do {
            try await player.pause()
            isPlaying = false
        } catch {
            print("Failed to pause: \(error)")
        }
    }
    
    func togglePlayPause() async {
        guard currentVideo != nil else { return }
        
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
