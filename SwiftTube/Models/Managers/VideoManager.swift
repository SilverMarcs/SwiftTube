//
//  NativeVideoManager.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 15/10/2025.
//

import AVKit
import Foundation
@preconcurrency import YouTubeKit

@Observable
class VideoManager {
    private(set) var currentVideo: Video? = nil
    private(set) var player: AVPlayer?

    var isExpanded: Bool = false
    var isSetting: Bool = false
    private let store = CloudStoreManager.shared
    private let fetchingSettings = FetchingSettings()

    func setVideo(_ video: Video, autoPlay: Bool = true) {
        isExpanded = autoPlay
           persistCurrentTime()
        
        guard video.id != currentVideo?.id else {
            return
        }

        player?.pause()
        isSetting = true

        currentVideo = video
        store.addToHistory(video.id)

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

            // Fetch stream URL on demand using YouTubeKit
            let methods = fetchingSettings.methods
            let youtube = YouTube(videoID: video.id, methods: methods)
            let streams = try await youtube.streams
            guard let stream = streams
                .filterVideoAndAudio()
                .filter({ $0.isNativelyPlayable })
                .highestResolutionStream()
            else {
                throw NSError(domain: "VideoManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No playable stream found"])
            }
            let playerItem = AVPlayerItem(url: stream.url)

            #if !os(macOS)
                playerItem.externalMetadata = await createMetadataItems(for: video)
            #endif

            if let existingPlayer = player {
                existingPlayer.replaceCurrentItem(with: playerItem)
            } else {
                player = AVPlayer(playerItem: playerItem)
            }

            let savedProgress = store.getWatchProgress(videoId: video.id)
            if savedProgress > 5 {
                let time = CMTime(seconds: savedProgress, preferredTimescale: 1)
                await player?.seek(to: time)
            }

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

    // MARK: - Persistence
    func persistCurrentTime() {
        guard let player = player, let videoId = currentVideo?.id else { return }
        let seconds = player.currentTime().seconds
        guard seconds.isFinite, seconds > 0 else { return }
        store.setWatchProgress(videoId: videoId, progress: seconds)
    }
}
