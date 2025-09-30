import SwiftUI
import Combine
import SwiftData
import YouTubePlayerKit

@Observable
class VideoManager {
    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()
    @ObservationIgnored
    private var player: YouTubePlayer?
    
    var isExpanded: Bool = false
    var playbackState: YouTubePlayer.PlaybackState? = nil
    var currentVideo: Video? = nil
    
    // Expose player for the UI
    var youTubePlayer: YouTubePlayer? {
        player
    }
    
    init() {
        setupPlayer()
    }
    
    /// Start playing a video
    func startPlaying(_ video: Video) {
        guard currentVideo?.id != video.id else { return }
        
        // Save progress of current video if any
        if let current = currentVideo {
            captureCurrentProgress(for: current)
        }
        
        // Update to new video
        currentVideo = video
        video.lastWatchedAt = Date()
        
        // Ensure player exists
        if player == nil {
            setupPlayer()
        }
        
        isExpanded = true
        
        // Load and play new video with progress restoration
        Task {
            await loadAndPlay(video)
        }
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
        if let video = currentVideo {
            captureCurrentProgress(for: video)
        }
        currentVideo = nil
        isExpanded = false
        
        // Pause the player but keep it alive for faster switching
        Task {
            await pause()
        }
    }
    
    func play() async {
        guard let player else { return }
        do {
            try await player.play()
        } catch {
            print("Failed to play: \(error)")
        }
    }
    
    func pause() async {
        guard let player else { return }
        do {
            try await player.pause()
        } catch {
            print("Failed to pause: \(error)")
        }
    }
    
    func togglePlayPause() async {
        if playbackState == .playing {
            await pause()
        } else {
            await play()
        }
    }
    
    private func setupPlayer() {
        // Create a single player instance with dummy video (will be replaced immediately)
        let initialPlayer = YouTubePlayer(
            source: .video(id: "dQw4w9WgXcQ"),
            parameters: .init(
                autoPlay: false,
                showControls: true
            ),
            configuration: .init(
                fullscreenMode: .system,
                allowsInlineMediaPlayback: true,
                allowsPictureInPictureMediaPlayback: true
            )
        )
        
        player = initialPlayer
        playbackState = initialPlayer.playbackState
        observePlayer(initialPlayer)
    }
    
    private func loadAndPlay(_ video: Video) async {
        guard let player = player else { return }
        
        do {
            // Use saved progress as start time if available
            let startTime: Measurement<UnitDuration>? = video.watchProgressSeconds > 5 
                ? Measurement(value: video.watchProgressSeconds, unit: UnitDuration.seconds)
                : nil
            
            // Load video with progress restoration built-in
            try await player.load(source: .video(id: video.id), startTime: startTime)
            
            // Start playing
            try await player.play()
        } catch {
            print("Failed to load and play video \(video.id): \(error)")
        }
    }
    
    private func observePlayer(_ player: YouTubePlayer) {
        // Observe playback state for UI updates
        player.playbackStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.playbackState = state
            }
            .store(in: &cancellables)
        
        // Observe current time for progress tracking (throttled to every 5 seconds)
        player.currentTimePublisher
            .throttle(for: .seconds(5), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] measurement in
                guard let self, let video = self.currentVideo else { return }
                let seconds = measurement.converted(to: .seconds).value
                video.updateWatchProgress(seconds)
            }
            .store(in: &cancellables)
    }
    
    private func captureCurrentProgress(for video: Video) {
        guard let player = player else { return }
        Task {
            do {
                let measurement = try await player.getCurrentTime()
                let seconds = measurement.converted(to: .seconds).value
                video.updateWatchProgress(seconds)
            } catch {
                // Ignore capture errors
            }
        }
    }
}
