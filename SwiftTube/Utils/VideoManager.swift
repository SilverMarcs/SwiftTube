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
    
    var isExpanded: Bool = false
    var playbackState: YouTubePlayer.PlaybackState? = nil
    var currentVideo: Video? = nil
    
    // Single YouTube player instance - more efficient
    @ObservationIgnored
    lazy var player: YouTubePlayer = {
        YouTubePlayer(
            source: .video(id: ""),
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
    }()
    
    init() {
        setupPlayerObservation()
    }
    
    /// Start playing a video
    func startPlaying(_ video: Video) {
        guard currentVideo?.id != video.id else { return }
        
        // Save progress of current video if any
        if let current = currentVideo {
            Task { await saveCurrentProgress(for: current) }
        }
        
        currentVideo = video
        video.lastWatchedAt = Date()
        
        // Load new video source
        isExpanded = true
        Task {
            try? await player.load(source: .video(id: video.id))
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
            Task { await saveCurrentProgress(for: video) }
        }
        currentVideo = nil
        isExpanded = false
        // Clear player by loading empty source
        Task {
           try? await player.load(source: .video(id: ""))
        }
    }
    
    func play() async {
        try? await player.play()
    }
    
    func pause() async {
        try? await player.pause()
    }
    
    func togglePlayPause() async {
        if playbackState == .playing {
            await pause()
        } else {
            await play()
        }
    }
    
    private func setupPlayerObservation() {
        // Observe playback state
        player.playbackStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.playbackState = state
                if state == .ended {
                    self?.handleVideoEnded()
                }
            }
            .store(in: &cancellables)
        
        // Observe player ready state for progress restoration
        player.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                if state == .ready {
                    self?.restoreProgressIfNeeded()
                    self?.startProgressTracking()
                }
            }
            .store(in: &cancellables)
    }
    
    private func startProgressTracking() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task {
                await self?.updateProgress()
            }
        }
    }
    
    private func updateProgress() async {
        guard let video = currentVideo else { return }
        do {
            let measurement = try await player.getCurrentTime()
            let seconds = measurement.converted(to: .seconds).value
            video.updateWatchProgress(seconds)
        } catch {
            // Ignore errors
        }
    }
    
    private func saveCurrentProgress(for video: Video) async {
        do {
            let measurement = try await player.getCurrentTime()
            let seconds = measurement.converted(to: .seconds).value
            video.updateWatchProgress(seconds)
        } catch {
            // Ignore errors
        }
    }
    
    private func restoreProgressIfNeeded() {
        guard let video = currentVideo, video.watchProgressSeconds > 5 else { return }
        
        Task {
            do {
                let target = Measurement(value: video.watchProgressSeconds, unit: UnitDuration.seconds)
                try await player.seek(to: target, allowSeekAhead: true)
            } catch {
                print("Failed to restore progress: \(error)")
            }
        }
    }
    
    private func handleVideoEnded() {
        guard let video = currentVideo else { return }
        if let duration = video.duration {
            video.updateWatchProgress(Double(duration))
        }
    }
    
    deinit {
        progressTimer?.invalidate()
    }
}
