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
    var isExpanded: Bool = false
    var isPlaying: Bool = false
    
    var youTubePlayer: YouTubePlayer? {
        player
    }

    
    // Temporarily store current video when entering Shorts view
    private var temporaryStoredVideo: Video?
    
    @ObservationIgnored
    private var player: YouTubePlayer?
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
    
    func togglePlayPause() async {
        if playbackState == .playing {
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
    
    private func handleCurrentVideoChange(from oldVideo: Video?, to newVideo: Video?) {
        if let oldVideo, let player {
            captureSnapshot(for: oldVideo, player: player)
        }
        cancellables.removeAll()
        playbackState = nil
        player = nil
        restoredVideoID = nil
        
        guard let newVideo else { return }
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
}
