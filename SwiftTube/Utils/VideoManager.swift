import SwiftUI
import Combine
import SwiftData
import YouTubePlayerKit

@MainActor
@Observable
class VideoManager {
    var currentVideo: Video? {
        didSet {
            guard oldValue?.id != currentVideo?.id else { return }
            handleCurrentVideoChange(from: oldValue, to: currentVideo)
        }
    }
    var isExpanded: Bool = false {
        didSet {
            // When transitioning from expanded to mini player, check for auto-resume
            if oldValue && !isExpanded {
                scheduleAutoResumeCheck()
            }
        }
    }
    var isPlaying: Bool = false
    
    var youTubePlayer: YouTubePlayer? {
        player
    }

    
    // Temporarily store current video when entering Shorts view
    private var temporaryStoredVideo: Video?
    
    @ObservationIgnored
    private var player: YouTubePlayer?
    @ObservationIgnored
    private var userDidPause: Bool = false
    @ObservationIgnored
    private var wasPlayingBeforeStateChange: Bool = false
    @ObservationIgnored
    private var playbackState: YouTubePlayer.PlaybackState? {
        didSet {
            let newIsPlaying = playbackState == .playing
            if isPlaying != newIsPlaying {
                isPlaying = newIsPlaying
            }
        }
    }
    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()
    @ObservationIgnored
    private var restoredVideoID: String?
    
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
    
    /// Play without marking as user-initiated (for auto-resume scenarios)
    private func playWithoutUserTracking() async {
        guard let player else { return }
        do {
            try await player.play()
        } catch {
            print("Failed to auto-play: \(error)")
        }
    }
    
    func togglePlayPause() async {
        if playbackState == .playing {
            userDidPause = true
            await pause()
        } else {
            userDidPause = false
            await play()
        }
    }
    
    /// Schedule an auto-resume check after a brief delay to handle state transitions
    private func scheduleAutoResumeCheck() {
        // Store the current playing state before potential auto-pause
        wasPlayingBeforeStateChange = isPlaying
        
        // Check after a brief delay to see if we should auto-resume
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            await checkAndAutoResume()
        }
    }
    
    /// Check if we should auto-resume after a state change
    private func checkAndAutoResume() async {
        // Only auto-resume if:
        // 1. We were playing before the state change
        // 2. User didn't manually pause
        // 3. Player is currently not playing
        // 4. We have a valid player
        guard wasPlayingBeforeStateChange,
              !userDidPause,
              !isPlaying,
              player != nil else {
            return
        }
        
        print("Auto-resuming video after state change")
        await playWithoutUserTracking()
    }
    
    /// Handle placement change in mini player (inline to non-inline or vice versa)
    func handlePlacementChange() {
        scheduleAutoResumeCheck()
    }
    
    /// Handle tab change which might cause auto-pause in mini player
//    func handleTabChange() {
//        scheduleAutoResumeCheck()
//    }
    
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
    
    private func handleCurrentVideoChange(from oldVideo: Video?, to newVideo: Video?) {
        if let oldVideo, let player {
            captureSnapshot(for: oldVideo, player: player)
        }
        cancellables.removeAll()
        playbackState = nil
        player = nil
        restoredVideoID = nil
        // Reset user pause state for new video
        userDidPause = false
        wasPlayingBeforeStateChange = false
        
        guard let newVideo else { return }
        
        // Update history tracking
        newVideo.lastWatchedAt = Date()
        
        let newPlayer = makePlayer(for: newVideo)
        player = newPlayer
        playbackState = newPlayer.playbackState
        observePlayer(newPlayer)
    }
    
    private func makePlayer(for video: Video) -> YouTubePlayer {
        YouTubePlayer(
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
        player.playbackStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                let previousState = self.playbackState
                self.playbackState = state
                
                // Handle auto-pause detection and resume
                if previousState == .playing && state == .paused && !self.userDidPause {
                    // This might be an auto-pause, schedule a resume check
                    Task {
                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                        await self.handlePotentialAutoPause()
                    }
                }
                
                if state == .ended {
                    self.markVideoAsCompleted()
                }
            }
            .store(in: &cancellables)
        
        player.currentTimePublisher
            .throttle(for: .seconds(5), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] measurement in
                guard let self else { return }
                self.persistCurrentProgress(measurement)
            }
            .store(in: &cancellables)

        player.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self, state == .ready else { return }
                self.restoreProgressIfNeeded(for: player)
            }
            .store(in: &cancellables)
    }
    
    private func persistCurrentProgress(_ measurement: Measurement<UnitDuration>) {
        guard let video = currentVideo else { return }
        let seconds = measurement.converted(to: .seconds).value
        persistWatchProgress(seconds: seconds, for: video)
    }
    
    private func captureSnapshot(for video: Video, player: YouTubePlayer) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let measurement = try await player.getCurrentTime()
                let seconds = measurement.converted(to: .seconds).value
                self.persistWatchProgress(seconds: seconds, for: video, force: true)
            } catch {
                // Ignore snapshot errors
            }
        }
    }
    
    private func markVideoAsCompleted() {
        guard let video = currentVideo else { return }
        if let duration = video.duration {
            persistWatchProgress(seconds: Double(duration), for: video, force: true)
        }
    }
    
    private func restoreProgressIfNeeded(for player: YouTubePlayer) {
        guard let video = currentVideo else { return }
        guard restoredVideoID != video.id else { return }
        guard video.watchProgressSeconds > 5 else {
            restoredVideoID = video.id
            return
        }

        restoredVideoID = video.id
        Task { @MainActor in
            do {
                let target = Measurement(value: video.watchProgressSeconds, unit: UnitDuration.seconds)
                try await player.seek(to: target, allowSeekAhead: true)
            } catch {
                print("Failed to restore watch progress: \(error)")
            }
        }
    }

    private func persistWatchProgress(seconds: Double, for video: Video, force: Bool = false) {
        var sanitized = max(0, seconds)
        if let duration = video.duration {
            sanitized = min(sanitized, Double(duration))
        }
        if !force, abs(video.watchProgressSeconds - sanitized) < 1 { return }
        video.watchProgressSeconds = sanitized
    }
    
    /// Handle potential auto-pause and resume if appropriate
    private func handlePotentialAutoPause() async {
        // Only auto-resume if user didn't manually pause and we're currently paused
        guard !userDidPause,
              playbackState == .paused,
              player != nil else {
            return
        }
        
        print("Detected auto-pause, attempting to resume")
        await playWithoutUserTracking()
    }
}
