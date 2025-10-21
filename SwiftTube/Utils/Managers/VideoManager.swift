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
    func setVideo(_ video: Video, autoPlay: Bool = true) {
        isExpanded = autoPlay
        
        guard video.id != currentVideo?.id else {
            return
        }
        
        player?.pause()
        isSetting = true
        
        currentVideo = video
        userDefaults.addToHistory(video.id)
        
        Task {
            await loadVideoStream(autoPlay: autoPlay)
            isSetting = false
        }
    }
    
    /// Toggle play/pause state
    func togglePlayPause() {
        guard let player else { return }
        
        if isPlaying {
            player.pause()
            #if !os(macOS)
            try? AVAudioSession.sharedInstance().setActive(false)
            #endif
        } else {
            player.play()
            #if !os(macOS)
            try? AVAudioSession.sharedInstance().setActive(true)
            #endif
        }
    }
    
    // MARK: - Private Methods
     private func loadVideoStream(autoPlay: Bool) async {
         do {
             guard let video = currentVideo else { return }
             let youtube = YouTube(videoID: video.id, methods: [.local, .remote])
             let streams = try await youtube.streams
             
             guard let stream = streams
                 .filterVideoAndAudio()
                 .filter({ $0.isNativelyPlayable })
 //                .filter({ ($0.videoResolution ?? 0) <= 1440 }) // Filter to 1440p or lower
                 .highestResolutionStream() else {
                 return
             }
             
             let playerItem = AVPlayerItem(url: stream.url)
             
             // Remove existing time observer before replacing item
             removeTimeObserver()
             
             if let existingPlayer = player {
                 existingPlayer.replaceCurrentItem(with: playerItem)
             } else {
                 player = AVPlayer(playerItem: playerItem)
                 setupPlaybackStatusObserver()
             }
             
             // Seek to saved progress for the NEW video if available
             let savedProgress = userDefaults.getWatchProgress(videoId: video.id)
             if savedProgress > 5 {
                 let time = CMTime(seconds: savedProgress, preferredTimescale: 1)
                 await player?.seek(to: time)
             }
             
             // Setup time observer AFTER seeking to correct position
             setupTimeObserver()
             
             if autoPlay {
                 player?.play()
                 #if !os(macOS)
                 try? AVAudioSession.sharedInstance().setActive(true)
                 #endif
             }
             
         } catch {
             print("YouTubeKit error: \(error)")
         }
     }
    
    
    // MARK: - Observers
    private func setupTimeObserver() {
        guard let player, let video = currentVideo else { return }
        
        removeTimeObserver()
        
        // Capture the video ID at observer setup time to avoid tracking progress for the wrong video
        let videoId = video.id
        self.timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 10, preferredTimescale: 1),
            queue: .main
        ) { [weak self] time in
            guard let self = self else { return }
            self.userDefaults.setWatchProgress(videoId: videoId, progress: time.seconds)
        }
    }
    
    /// Setup KVO observer for player's playback status
    private func setupPlaybackStatusObserver() {
        guard let player else { return }
        
        playbackStatusObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            self?.isPlaying = player.timeControlStatus == .playing
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
    
    /// Remove time observer
    private func removeTimeObserver() {
        guard let player, let observer = timeObserver else { return }
        player.removeTimeObserver(observer)
        timeObserver = nil
    }
}
