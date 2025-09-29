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
    
    var youTubePlayer: YouTubePlayer?
    
    @ObservationIgnored
    private var player: YouTubePlayer? {
        didSet {
            youTubePlayer = player
        }
    }
    @ObservationIgnored
    private var playbackState: YouTubePlayer.PlaybackState? {
        didSet {
            let newIsPlaying = playbackState == .playing
            // Only update isPlaying if it's actually different, to avoid overriding optimistic updates
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
            // Optimistically set isPlaying to true
            isPlaying = true
        } catch {
            print("Failed to play: \(error)")
            isPlaying = false
        }
    }
    
    func pause() async {
        guard let player else { return }
        do {
            try await player.pause()
            // Optimistically set isPlaying to false
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
    
    func expand() {
        isExpanded = true
    }
    
    func dismiss() {
        currentVideo = nil
        isExpanded = false
    }
    
    func togglePlayback() {
        Task {
            await togglePlayPause()
        }
    }
    
    private func handleCurrentVideoChange(from oldVideo: Video?, to newVideo: Video?) {
        if let oldVideo, let player {
            captureSnapshot(for: oldVideo, player: player)
        }
        cancellables.removeAll()
        playbackState = nil
        player = nil
        youTubePlayer = nil
        restoredVideoID = nil
        
        guard let newVideo else { return }
        
        // Update history tracking
        newVideo.lastWatchedAt = Date()
        
        let newPlayer = makePlayer(for: newVideo)
        player = newPlayer
        youTubePlayer = newPlayer
        playbackState = newPlayer.playbackState
        // Set isPlaying to true since we're about to play
        isPlaying = true
        observePlayer(newPlayer)
        Task { [weak self] in
            guard let self else { return }
            await self.play()
        }
    }
    
    private func makePlayer(for video: Video) -> YouTubePlayer {
        YouTubePlayer(
            source: .video(id: video.id),
            parameters: .init(
                autoPlay: true,
                showControls: true,
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
                    self.isPlaying = false
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
