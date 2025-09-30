import SwiftUI
import Combine
import SwiftData
import YouTubePlayerKit

@Observable
class ShortsManager {
    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()
    
    var player: YouTubePlayer?
    var playbackState: YouTubePlayer.PlaybackState? = nil
    var currentVideo: Video? = nil
    var currentIndex: Int = 0
    
    /// Start playing a short video
    func startPlaying(_ video: Video, at index: Int) {
        guard currentVideo?.id != video.id else { return }

        // Update to new video
        currentVideo = video
        currentIndex = index
        video.lastWatchedAt = Date()
        
        // Create player if needed and load video
        createPlayerIfNeeded(id: video.id)
        loadVideo(video)
    }
    
    /// Check if a specific video is currently playing
    func isPlaying(_ video: Video) -> Bool {
        currentVideo?.id == video.id
    }
    
    /// Switch to a different short video
    func switchTo(_ video: Video, at index: Int) {
        currentVideo = video
        currentIndex = index
        video.lastWatchedAt = Date()
        loadVideo(video)
    }
    
    func togglePlayPause() async {
        guard let player else { return }
        
        if playbackState == .playing {
            try? await player.pause()
        } else {
            try? await player.play()
        }
    }
    
    func pause() async {
        guard let player else { return }
        try? await player.pause()
    }
    
    func play() async {
        guard let player else { return }
        try? await player.play()
    }
    
    private func createPlayerIfNeeded(id: String) {
        guard player == nil else { return }
        
        let newPlayer = YouTubePlayer(
            source: .video(id: id), // Placeholder, will be replaced
            parameters: .init(autoPlay: true, loopEnabled: true, showControls: false), // Auto-play for shorts, loop enabled, no controls
            configuration: .init(
                fullscreenMode: .system,
                allowsInlineMediaPlayback: true,
                allowsPictureInPictureMediaPlayback: false // Disable PiP for shorts
            )
        )
        
        player = newPlayer
        playbackState = newPlayer.playbackState
        setupPlayerObservers()
    }
    
    private func loadVideo(_ video: Video) {
        guard let player else { return }
        
        // For shorts, we typically want to start from the beginning or from last watched position
        let startTime = video.watchProgressSeconds > 5 
            ? Measurement(value: video.watchProgressSeconds, unit: UnitDuration.seconds)
            : nil
            
        Task {
            try? await player.load(source: .video(id: video.id), startTime: startTime)
            try? await player.play()
        }
    }
    
    private func setupPlayerObservers() {
        guard let player else { return }
        
        // Track playback state
        player.playbackStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.playbackState = state
            }
            .store(in: &cancellables)
        
        // Track progress every 5 seconds for shorts
        player.currentTimePublisher
            .throttle(for: .seconds(5), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] time in
                self?.updateVideoProgress(time)
            }
            .store(in: &cancellables)
    }
    
    private func updateVideoProgress(_ time: Measurement<UnitDuration>) {
        guard let video = currentVideo else { return }
        let seconds = time.converted(to: .seconds).value
        video.updateWatchProgress(seconds)
    }
}
