import SwiftUI
import Combine
import SwiftData
import YouTubePlayerKit

/// A value type that encapsulates a video and its associated YouTube player
struct PlayingVideo: Equatable {
    let video: Video
    let player: YouTubePlayer
    
    init(video: Video) {
        self.video = video
        self.player = YouTubePlayer(
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
    
    static func == (lhs: PlayingVideo, rhs: PlayingVideo) -> Bool {
        lhs.video.id == rhs.video.id
    }
}

@MainActor
@Observable
class VideoManager {
    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()
    @ObservationIgnored
    private var restoredVideoID: String?
    
    var isExpanded: Bool = false
    var playbackState: YouTubePlayer.PlaybackState? = nil
    
    // Main API - use this for new code
    var playingVideo: PlayingVideo? {
        get { _playingVideo }
        set { _playingVideo = newValue }
    }
    
    private var _playingVideo: PlayingVideo? {
        didSet {
            guard oldValue?.video.id != _playingVideo?.video.id else { return }
            handlePlayingVideoChange(from: oldValue, to: _playingVideo)
            if _playingVideo != nil {
                isExpanded = true
            }
        }
    }
    
    /// Start playing a video
    func startPlaying(_ video: Video) {
        _playingVideo = PlayingVideo(video: video)
    }
    
    /// Check if a specific video is currently playing
    func isPlaying(_ video: Video) -> Bool {
        _playingVideo?.video.id == video.id
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
        _playingVideo = nil
        isExpanded = false
    }
    
    func play() async {
        guard let player = _playingVideo?.player else { return }
        try? await player.play()
    }
    
    func pause() async {
        guard let player = _playingVideo?.player else { return }
        try? await player.pause()
    }
    
    func togglePlayPause() async {
        if playbackState == .playing {
            await pause()
        } else {
            await play()
        }
    }
    
    private func handlePlayingVideoChange(from oldPlayingVideo: PlayingVideo?, to newPlayingVideo: PlayingVideo?) {
        if let oldVideo = oldPlayingVideo?.video {
            captureSnapshot(for: oldVideo, player: oldPlayingVideo?.player)
        }
        cancellables.removeAll()
        playbackState = nil
        restoredVideoID = nil
        
        guard let newPlayingVideo else { return }
        
        // Update history tracking
        newPlayingVideo.video.lastWatchedAt = Date()
        
        observePlayer(newPlayingVideo.player)
        Task { [weak self] in
            guard let self else { return }
            await self.play()
        }
    }
    
    private func observePlayer(_ player: YouTubePlayer) {
        player.playbackStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                self.playbackState = state
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
                self.restoreProgressIfNeeded()
            }
            .store(in: &cancellables)
    }
    
    private func persistCurrentProgress(_ measurement: Measurement<UnitDuration>) {
        guard let video = _playingVideo?.video else { return }
        let seconds = measurement.converted(to: .seconds).value
        persistWatchProgress(seconds: seconds, for: video)
    }
    
    private func captureSnapshot(for video: Video, player: YouTubePlayer?) {
        guard let player else { return }
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
        guard let video = _playingVideo?.video else { return }
        if let duration = video.duration {
            persistWatchProgress(seconds: Double(duration), for: video, force: true)
        }
    }
    
    private func restoreProgressIfNeeded() {
        guard let playingVideo = _playingVideo else { return }
        let video = playingVideo.video
        let player = playingVideo.player
        
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
}
