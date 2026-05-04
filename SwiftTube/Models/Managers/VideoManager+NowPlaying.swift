//
//  VideoManager+NowPlaying.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 15/10/2025.
//

import AVKit
import MediaPlayer
#if canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#else
import AppKit
typealias PlatformImage = NSImage
#endif

extension VideoManager {
    func registerRemoteCommandsIfNeeded() {
        guard !hasRegisteredRemoteCommands else { return }
        hasRegisteredRemoteCommands = true

        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            guard let player = self?.player else { return .commandFailed }
            player.play()
            return .success
        }

        center.pauseCommand.addTarget { [weak self] _ in
            guard let player = self?.player else { return .commandFailed }
            player.pause()
            return .success
        }

        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self, self.player != nil else { return .commandFailed }
            self.togglePlayPause()
            return .success
        }

        center.skipForwardCommand.preferredIntervals = [10]
        center.skipForwardCommand.addTarget { [weak self] event in
            guard let player = self?.player else { return .commandFailed }
            let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? 10
            let target = player.currentTime() + CMTime(seconds: interval, preferredTimescale: 600)
            player.seek(to: target) { _ in
                self?.updateNowPlayingPlaybackInfo()
            }
            return .success
        }

        center.skipBackwardCommand.preferredIntervals = [10]
        center.skipBackwardCommand.addTarget { [weak self] event in
            guard let player = self?.player else { return .commandFailed }
            let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? 10
            let target = player.currentTime() - CMTime(seconds: interval, preferredTimescale: 600)
            player.seek(to: target) { _ in
                self?.updateNowPlayingPlaybackInfo()
            }
            return .success
        }

        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let player = self?.player,
                  let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let target = CMTime(seconds: event.positionTime, preferredTimescale: 600)
            player.seek(to: target) { _ in
                self?.updateNowPlayingPlaybackInfo()
            }
            return .success
        }
    }

    func attachPlayerObservers(to player: AVPlayer) {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }

        let interval = CMTime(seconds: 1, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            self?.updateNowPlayingPlaybackInfo()
        }

        rateObservation = player.observe(\.rate, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.updateNowPlayingPlaybackInfo() }
        }

        statusObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.updateNowPlayingPlaybackInfo() }
        }

        durationObservation = player.observe(\.currentItem?.duration, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.updateNowPlayingPlaybackInfo() }
        }
    }

    func updateNowPlayingMetadata(for video: Video) async {
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = video.title
        info[MPMediaItemPropertyArtist] = video.channel.title
        info[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.video.rawValue

        if !video.thumbnailURL.isEmpty, let url = URL(string: video.thumbnailURL) {
            if let (data, _) = try? await URLSession.shared.data(from: url),
               let image = PlatformImage(data: data) {
                let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                info[MPMediaItemPropertyArtwork] = artwork
            }
        }

        // Don't clobber playback fields written by updateNowPlayingPlaybackInfo
        guard currentVideo?.id == video.id else { return }
        for (key, value) in info {
            nowPlayingInfo[key] = value
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        MPNowPlayingInfoCenter.default().playbackState = .playing
    }

    func updateNowPlayingPlaybackInfo() {
        guard let player else { return }

        let elapsed = player.currentTime().seconds
        if elapsed.isFinite {
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        }

        if let duration = player.currentItem?.duration.seconds, duration.isFinite, duration > 0 {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        }

        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player.rate
        nowPlayingInfo[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        MPNowPlayingInfoCenter.default().playbackState = (player.rate > 0) ? .playing : .paused
    }

    func clearNowPlayingInfo() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        rateObservation = nil
        statusObservation = nil
        durationObservation = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
    }
}
