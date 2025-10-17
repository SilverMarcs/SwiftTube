//
//  NativeVideoManager.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 15/10/2025.
//

import Foundation
import AVKit
import YouTubeKit

@Observable
class VideoManager {
    private(set) var currentVideo: Video? = nil
    private(set) var player: AVPlayer?
    private(set) var isPlaying: Bool = false
    
    var isExpanded: Bool = false
    var isSetting: Bool = false
    var isMiniPlayerVisible: Bool = true
    
    private var timeObserver: Any?
    private var playbackStatusObservation: NSKeyValueObservation?
    private let userDefaults = UserDefaultsManager.shared
    
    // MARK: - Public Methods
    
    /// Set the current video with optional autoplay
    /// - Parameters:
    ///   - video: The video to set as current, or nil to clear
    ///   - autoPlay: Whether to automatically start playback (default: true)
    func setVideo(_ video: Video?, autoPlay: Bool = true) {
        player?.pause()
        isSetting = true
        guard currentVideo?.id != video?.id else { return }
        guard let video else { return }
        
        // New video selected
        isExpanded = autoPlay // Auto-expand only if autoplaying (iOS only)
        currentVideo = video
        userDefaults.addToHistory(video.id)
        Task {
            await loadVideoStream(for: video, autoPlay: autoPlay)
            isSetting = false
        }
    }
    
    /// Toggle play/pause state
    func togglePlayPause() {
        guard let player else { return }
        
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
    }
    
    /// Pause timer tracking (call when app goes to background)
    func pauseTimerTracking() {
        removeTimeObserver()
    }
    
    /// Resume timer tracking (call when app comes to foreground)
    func resumeTimerTracking() {
        guard timeObserver == nil, player != nil else { return }
        setupTimeObserver()
    }
    
    /// Load a video from a URL
    /// - Parameters:
    ///   - url: The video URL to load
    ///   - video: The Video object associated with this playback
    ///   - autoPlay: Whether to auto-play the video
    private func loadVideo(url: URL, for video: Video, autoPlay: Bool = true) {
        // Create player item with the URL
        let playerItem = AVPlayerItem(url: url)
        
        // Create or replace player
        if let existingPlayer = player {
            existingPlayer.replaceCurrentItem(with: playerItem)
        } else {
            player = AVPlayer(playerItem: playerItem)
            setupPlaybackStatusObserver()
        }
        
        // Set up time observer
        setupTimeObserver()
        
        // Seek to saved progress if available
        let savedProgress = userDefaults.getWatchProgress(videoId: video.id)
        if savedProgress > 5 {
            let time = CMTime(seconds: savedProgress, preferredTimescale: 1)
            player?.seek(to: time)
        }
        
        // Auto-play if requested
        if autoPlay {
            player?.play()
        }
    }
    
    // MARK: - Private Methods
    
    private func loadVideoStream(for video: Video, autoPlay: Bool) async {
        do {
            // Use YouTubeKit to get the stream
            let youtube = YouTube(videoID: video.id, methods: [.local, .remote])
            let streams = try await youtube.streams
            
            // Get the best stream with both video and audio
            guard let stream = streams
                .filterVideoAndAudio()
                .filter({ $0.isNativelyPlayable })
//                .filter({ ($0.videoResolution ?? 0) <= 1440 }) // Filter to 1440p or lower
                .highestResolutionStream() else {
                return
            }
            
            // Load video in the manager
            loadVideo(url: stream.url, for: video, autoPlay: autoPlay)
            
        } catch {
            print("YouTubeKit error: \(error)")
        }
    }
    
    
    // MARK: - Observers
    private func setupTimeObserver() {
        guard let player else { return }
        
        // Remove existing observer if any
        removeTimeObserver()
        
        self.timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 5, preferredTimescale: 1),
            queue: .main
        ) { [weak self] time in
            guard let self = self, let currentVideo = self.currentVideo else { return }
            currentVideo.updateWatchProgress(time.seconds)
        }
    }
    
    /// Setup KVO observer for player's playback status
    private func setupPlaybackStatusObserver() {
        guard let player else { return }
        
        playbackStatusObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            self?.isPlaying = player.timeControlStatus == .playing
        }
    }
    
    /// Remove time observer
    private func removeTimeObserver() {
        guard let player, let observer = timeObserver else { return }
        player.removeTimeObserver(observer)
        timeObserver = nil
    }
}
