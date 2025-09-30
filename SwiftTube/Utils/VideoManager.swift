import SwiftUI
import Combine
import SwiftData
import YouTubePlayerKit

@Observable
class VideoManager {
    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()
    
    var player: YouTubePlayer?
    var isExpanded: Bool = false
    var playbackState: YouTubePlayer.PlaybackState? = nil
    var currentVideo: Video? = nil
    
    /// Start playing a video
    func startPlaying(_ video: Video) {
        guard currentVideo?.id != video.id else { return }

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
    
    func togglePlayPause() async {
        guard let player else { return }
        
        if playbackState == .playing {
            try? await player.pause()
        } else {
            try? await player.play()
        }
    }
    
    private func createPlayerIfNeeded(id: String) {
        guard player == nil else { return }
        
        let newPlayer = YouTubePlayer(
            source: .video(id: id), // Placeholder, will be replaced
            parameters: .init(autoPlay: false, showControls: true),
            configuration: .init(
                fullscreenMode: .system,
                allowsInlineMediaPlayback: true,
                allowsPictureInPictureMediaPlayback: true
            )
        )
        
        player = newPlayer
        playbackState = newPlayer.playbackState
        setupPlayerObservers()
    }
    
    private func loadVideo(_ video: Video) {
        guard let player else { return }
        
        // Simple approach: load video, then seek if needed
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
        
        // Track progress every 5 seconds
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
