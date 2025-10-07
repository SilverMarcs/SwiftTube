import SwiftUI

@MainActor
@Observable
class VideoManager {
    private(set) var player: YTPlayer?
    private(set) var isPlaying: Bool = false
    
    var playbackPosition: TimeInterval = 0
    var playbackDuration: TimeInterval?
    
    var isExpanded: Bool = false
    var currentVideo: Video? = nil {
        didSet {
            if !isSettingVideoWithoutAutoplay {
                handleVideoChange(from: oldValue, to: currentVideo, autoPlay: true)
            }
        }
    }
    var isMiniPlayerVisible: Bool = true
    #if os(macOS)
    var isMediaPlayerWindowOpen: Bool = false
    #endif
    
    private var playbackLoopTask: Task<Void, Never>?
    private var lastPersistedProgress: TimeInterval = 0
    private let userDefaults = UserDefaultsManager.shared
    private var isSettingVideoWithoutAutoplay = false
    
    /// Set video without autoplay (useful for restoring from history)
    func setVideoWithoutAutoplay(_ video: Video) {
        isSettingVideoWithoutAutoplay = true
        defer { isSettingVideoWithoutAutoplay = false }
        
        let oldValue = currentVideo
        currentVideo = video
        handleVideoChange(from: oldValue, to: video, autoPlay: false)
    }
    
    /// Handle video change - automatically sets up player and loads video
    private func handleVideoChange(from oldVideo: Video?, to newVideo: Video?, autoPlay: Bool) {
        guard oldVideo?.id != newVideo?.id else { return }
        
        playbackDuration = newVideo?.duration.map(Double.init)
        playbackPosition = 0
        lastPersistedProgress = 0
        
        if let newVideo {
            isPlaying = autoPlay
            #if !os(macOS)
            isExpanded = autoPlay
            #endif
            userDefaults.addToHistory(newVideo.id)
            createPlayerIfNeeded(autoPlay: autoPlay)
            
            let resumeProgress = userDefaults.getWatchProgress(videoId: newVideo.id)
            let startTime = resumeProgress > 5 ? resumeProgress : nil
            playbackPosition = startTime ?? 0
            lastPersistedProgress = playbackPosition
            startPlaybackMonitoring()
            loadVideo(newVideo, startTime: startTime, autoPlay: autoPlay)
        } else {
            isPlaying = false
            playbackDuration = nil
            playbackPosition = 0
            lastPersistedProgress = 0
            playbackLoopTask?.cancel()
            playbackLoopTask = nil
            Task {
                try? await player?.pause()
            }
        }
    }

    func dismiss() {
        isExpanded = false
        currentVideo = nil
    }
    
    func togglePlayPause() async {
        guard let player else { return }
        
        do {
            if try await player.playbackState == .playing {
                isPlaying = false
                try? await player.pause()
            } else {
                isPlaying = true
                try? await player.play()
            }
        } catch {
            isPlaying = true
            try? await player.play()
        }
    }
    
    func seek(by offset: TimeInterval) async {
        await seek(to: playbackPosition + offset)
    }
    
    func seek(to time: TimeInterval) async {
        guard let player else { return }
        let clamped = clampTime(time)
        do {
            try await player.seek(to: clamped)
        } catch {
            // ignore seek errors for now
        }
        playbackPosition = clamped
    }
    
    private func createPlayerIfNeeded(autoPlay: Bool) {
        guard player == nil else { return }
        let config = YTPlayer.Configuration(autoPlay: autoPlay, showControls: false)
        player = YTPlayer(configuration: config)
    }
    
    private func loadVideo(_ video: Video, startTime: TimeInterval?, autoPlay: Bool) {
        guard let player else { return }
        
        Task { [weak self] in
            do {
                try await player.load(videoId: video.id, startTime: startTime)
                if !autoPlay {
                    try? await player.pause()
                }
                if let duration = try? await player.duration, duration > 0 {
                    await MainActor.run {
                        self?.setPlaybackDurationIfNeeded(duration)
                    }
                }
            } catch {
                // No-op: errors are surfaced via player state
            }
        }
    }
    
    private func startPlaybackMonitoring() {
        playbackLoopTask?.cancel()
        playbackLoopTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard let self, let player = self.player else { break }
                guard let currentTime = try? await player.currentPlaybackTime else { continue }
                await MainActor.run {
                    self.handleTimeUpdate(currentTime)
                }
            }
        }
    }
    
    private func handleTimeUpdate(_ currentTime: TimeInterval) {
        let clamped = clampTime(currentTime)
        playbackPosition = clamped
        if clamped - lastPersistedProgress >= 10 || isAtPlaybackEnd(clamped) {
            lastPersistedProgress = clamped
            updateVideoProgress(clamped)
        }
    }
    
    private func clampTime(_ time: TimeInterval) -> TimeInterval {
        let lowerBound: TimeInterval = 0
        guard let playbackDuration else {
            return max(time, lowerBound)
        }
        return min(max(time, lowerBound), playbackDuration)
    }

    private func isAtPlaybackEnd(_ time: TimeInterval) -> Bool {
        guard let playbackDuration else { return false }
        return playbackDuration - time <= 0.5
    }
    
    private func setPlaybackDurationIfNeeded(_ duration: TimeInterval) {
        guard duration > 0 else { return }
        playbackDuration = duration
        if var video = currentVideo, video.duration == nil {
            video.duration = Int(duration.rounded())
            currentVideo = video
        }
    }
    
    private func updateVideoProgress(_ seconds: TimeInterval) {
        guard let video = currentVideo else { return }
        video.updateWatchProgress(seconds)
    }
}
