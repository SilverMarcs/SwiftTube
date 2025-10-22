//
//  NativeVideoManager.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 15/10/2025.
//

import AVKit
import Foundation
import YouTubeKit

@Observable
class VideoManager {
    private(set) var currentVideo: Video? = nil
    private(set) var player: AVPlayer?

    var isExpanded: Bool = false
    var isSetting: Bool = false

    private var timeObserver: Any?
    private let userDefaults = UserDefaultsManager.shared
    private let fetchingSettings = FetchingSettings()

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

    func togglePlayPause() {
        guard let player else { return }

        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
        }
    }

    // MARK: - Private Methods
    private func loadVideoStream(autoPlay: Bool) async {
        do {
            guard let video = currentVideo else { return }

            let youtube = YouTube(videoID: video.id, methods: fetchingSettings.methods)
            let streams = try await youtube.streams

            guard
                let stream =
                    streams
                    .filterVideoAndAudio()
                    .filter({ $0.isNativelyPlayable })
                    //                .filter({ ($0.videoResolution ?? 0) <= 1080 })
                    .highestResolutionStream()
            else {
                return
            }

            let playerItem = AVPlayerItem(url: stream.url)

            #if !os(macOS)
                playerItem.externalMetadata = await createMetadataItems(for: video)
            #endif

            removeTimeObserver()

            if let existingPlayer = player {
                existingPlayer.replaceCurrentItem(with: playerItem)
            } else {
                player = AVPlayer(playerItem: playerItem)
            }

            let savedProgress = userDefaults.getWatchProgress(videoId: video.id)
            if savedProgress > 5 {
                let time = CMTime(seconds: savedProgress, preferredTimescale: 1)
                await player?.seek(to: time)
            }

            setupTimeObserver()

            if autoPlay {
                player?.play()
            }

        } catch {
            print("YouTubeKit error: \(error)")
        }
    }

    // MARK: - Metadata Creation
    private func createMetadataItems(for video: Video) async -> [AVMetadataItem] {
        var metadata: [AVMetadataItem] = []

        // Title
        let titleItem = AVMutableMetadataItem()
        titleItem.identifier = .commonIdentifierTitle
        titleItem.value = video.title as NSString
        titleItem.extendedLanguageTag = "und"
        metadata.append(titleItem)

        // Artist (Channel name)
        let artistItem = AVMutableMetadataItem()
        artistItem.identifier = .iTunesMetadataTrackSubTitle
        artistItem.value = video.channel.title as NSString
        artistItem.extendedLanguageTag = "und"
        metadata.append(artistItem)

        // Artwork (thumbnail)
        if !video.thumbnailURL.isEmpty, let url = URL(string: video.thumbnailURL) {
            let artworkItem = AVMutableMetadataItem()
            artworkItem.identifier = .commonIdentifierArtwork
            artworkItem.dataType = kCMMetadataBaseDataType_PNG as String

            // Load thumbnail asynchronously using URLSession
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                artworkItem.value = data as NSData
                metadata.append(artworkItem)
            } catch {
                print("Failed to load thumbnail: \(error)")
            }
        }

        return metadata
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

    /// Resume timer tracking (call when app comes to foreground)
    func resumeTimerTracking() {
        guard timeObserver == nil, player != nil else { return }
        setupTimeObserver()
    }

    /// Remove time observer
    func removeTimeObserver() {
        guard let player, let observer = timeObserver else { return }
        player.removeTimeObserver(observer)
        timeObserver = nil
    }
}
