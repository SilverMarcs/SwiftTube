import SwiftUI
import Combine
import SwiftData
import YouTubePlayerKit

@Observable
class VideoManager {
    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()
    @ObservationIgnored
    private var progressTimer: Timer?
    @ObservationIgnored
    private var restoredVideoID: String?
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
        // No setup needed - player created per video
    }
    
    /// Start playing a video
    func startPlaying(_ video: Video) {
        guard currentVideo?.id != video.id else { return }
        
        // Save progress of current video if any
        if let current = currentVideo, let currentPlayer = player {
            captureSnapshot(for: current, player: currentPlayer)
        }
        
        // Clean up previous player
        cancellables.removeAll()
        playbackState = nil
        player = nil
        restoredVideoID = nil
        
        // Set new video and create new player
        currentVideo = video
        video.lastWatchedAt = Date()
        
        let newPlayer = makePlayer(for: video)
        player = newPlayer
        playbackState = newPlayer.playbackState
        observePlayer(newPlayer)
        
        isExpanded = true
        
        // Start playing
        Task {
            await play()
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
        if let video = currentVideo, let currentPlayer = player {
            captureSnapshot(for: video, player: currentPlayer)
        }
        currentVideo = nil
        isExpanded = false
        restoredVideoID = nil
        cancellables.removeAll()
        playbackState = nil
        player = nil

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
    
    private func makePlayer(for video: Video) -> YouTubePlayer {
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
    
    private func observePlayer(_ player: YouTubePlayer) {
        // Observe playback state for UI updates
        player.playbackStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                self.playbackState = state
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
        
        // Observe player ready state for progress restoration
        player.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                if state == .ready {
                    self?.restoreProgressIfNeeded(for: player)
                }
            }
            .store(in: &cancellables)
    }
    
    private func saveCurrentProgress(for video: Video) async {
        guard let player else { return }
        do {
            let measurement = try await player.getCurrentTime()
            let seconds = measurement.converted(to: .seconds).value
            video.updateWatchProgress(seconds)
        } catch {
            // Ignore errors
        }
    }
    
    private func captureSnapshot(for video: Video, player: YouTubePlayer) {
        Task {
            do {
                let measurement = try await player.getCurrentTime()
                let seconds = measurement.converted(to: .seconds).value
                video.updateWatchProgress(seconds)
            } catch {
                // Ignore snapshot errors
            }
        }
    }
    
    private func restoreProgressIfNeeded(for player: YouTubePlayer) {
        guard let video = currentVideo else { return }
        guard restoredVideoID != video.id else { return } // Prevent duplicate restoration
        guard video.watchProgressSeconds > 5 else {
            restoredVideoID = video.id // Mark as processed even if no restoration needed
            return
        }
        
        restoredVideoID = video.id // Mark as restored
        Task {
            do {
                let target = Measurement(value: video.watchProgressSeconds, unit: UnitDuration.seconds)
                try await player.seek(to: target, allowSeekAhead: true)
            } catch {
                print("Failed to restore watch progress: \(error)")
            }
        }
    }
    
    deinit {
        progressTimer?.invalidate()
    }
}
