//
//  NativeVideoManager.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 15/10/2025.
//

import AVFoundation
import AVKit
import Foundation
import MediaPlayer

@Observable
class VideoManager {
    private(set) var currentVideo: Video? = nil
    private(set) var player: AVPlayer?
    private(set) var sponsorSegments: [SponsorSegment] = []
    private(set) var currentSponsorSegment: SponsorSegment? = nil

    var isExpanded: Bool = false
    var isSetting: Bool = false
    private let store = CloudStoreManager.shared

    var timeObserverToken: Any?
    var rateObservation: NSKeyValueObservation?
    var statusObservation: NSKeyValueObservation?
    var durationObservation: NSKeyValueObservation?
    var nowPlayingInfo: [String: Any] = [:]
    var hasRegisteredRemoteCommands = false

    init() {
        registerRemoteCommandsIfNeeded()
    }

    deinit {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func setVideo(_ video: Video, autoPlay: Bool = true) {
        isExpanded = autoPlay
        persistCurrentTime()

        guard video.id != currentVideo?.id else {
            return
        }

        player?.pause()
        isSetting = true

        currentVideo = video
        sponsorSegments = []
        currentSponsorSegment = nil
        store.addToHistory(video)

        Task {
            await loadVideoStream(for: video, autoPlay: autoPlay)
            if self.currentVideo?.id == video.id {
                isSetting = false
            }
        }
    }

    private func loadVideoStream(for video: Video, autoPlay: Bool) async {
        await loadVideoStream(for: video, autoPlay: autoPlay, allowCacheRetry: true)
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
    private func loadVideoStream(for video: Video, autoPlay: Bool, allowCacheRetry: Bool) async {
        // If the requested video is no longer the current one, abort this task.
        guard currentVideo?.id == video.id else { return }

        let url: URL
        #if os(iOS)
        if let local = DownloadManager.shared.localURL(for: video.id) {
            url = local
        } else if let streamed = await StreamURLCache.shared.fetch(id: video.id) {
            url = streamed
        } else {
            print("YouTubeKit error: no playable stream for \(video.id)")
            return
        }
        #else
        if let streamed = await StreamURLCache.shared.fetch(id: video.id) {
            url = streamed
        } else {
            print("YouTubeKit error: no playable stream for \(video.id)")
            return
        }
        #endif

        let playerItem = AVPlayerItem(url: url)
        #if !os(macOS)
        playerItem.externalMetadata = await createMetadataItems(for: video)
        #endif

        // Ensure we're still targeting the same video before mutating the player
        guard currentVideo?.id == video.id else { return }
        if let existingPlayer = player {
            existingPlayer.replaceCurrentItem(with: playerItem)
        } else {
            let newPlayer = AVPlayer(playerItem: playerItem)
            player = newPlayer
            attachPlayerObservers(to: newPlayer)
        }

        let savedProgress = store.getWatchProgress(videoId: video.id)
        if savedProgress > 5 {
            let time = CMTime(seconds: savedProgress, preferredTimescale: 1)
            guard currentVideo?.id == video.id else { return }
            await player?.seek(to: time)
        }

        if autoPlay {
            player?.play()
        }

        await updateNowPlayingMetadata(for: video)
        updateNowPlayingPlaybackInfo()

        await applyNavigationMarkers(for: video, on: playerItem)

        // If the cached URL turns out to be stale (e.g. expired YouTube CDN ticket),
        // evict and retry once with a fresh fetch.
        Task { [weak self] in
            let ready = await awaitPlayerItemReady(playerItem)
            guard !ready, allowCacheRetry else { return }
            guard let self else { return }
            guard self.currentVideo?.id == video.id else { return }
            await StreamURLCache.shared.evict(id: video.id)
            await self.loadVideoStream(for: video, autoPlay: autoPlay, allowCacheRetry: false)
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

        // Description
        if !video.videoDescription.isEmpty {
            let descItem = AVMutableMetadataItem()
            descItem.identifier = .commonIdentifierDescription
            descItem.value = video.videoDescription as NSString
            descItem.extendedLanguageTag = "und"
            metadata.append(descItem)
        }

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

    // MARK: - Navigation Markers (chapters + sponsor segments)
    private func applyNavigationMarkers(for video: Video, on playerItem: AVPlayerItem) async {
        async let descriptionChapters = DescriptionChapterParser.parse(video.videoDescription)
        async let sponsors = SponsorBlockService.fetchSponsorSegments(for: video.id)
        let chapters = await descriptionChapters
        let segments = await sponsors

        guard self.currentVideo?.id == video.id else { return }
        self.sponsorSegments = segments
        refreshSponsorState()

        #if os(tvOS)
        let duration = Double(video.duration ?? 0)
        let markers = buildMarkers(chapters: chapters, sponsors: segments, totalDuration: duration > 0 ? duration : nil)
        guard !markers.isEmpty else { return }
        playerItem.navigationMarkerGroups = [AVNavigationMarkersGroup(title: nil, timedNavigationMarkers: markers)]
        #endif
    }

    func skipCurrentSponsorSegment() {
        guard let player, let segment = currentSponsorSegment else { return }
        // Optimistic clear so the button hides immediately on tap.
        currentSponsorSegment = nil
        player.seek(to: CMTime(seconds: segment.end, preferredTimescale: 600))
    }

    /// Called from the existing 1s periodic time observer in
    /// `attachPlayerObservers` and after sponsor segments load.
    func refreshSponsorStatePublic() {
        refreshSponsorState()
    }

    private func refreshSponsorState() {
        guard let player else {
            if currentSponsorSegment != nil { currentSponsorSegment = nil }
            return
        }
        let now = player.currentTime().seconds
        let next = sponsorSegments.first { now >= $0.start && now < $0.end }
        if next != currentSponsorSegment {
            currentSponsorSegment = next
        }
    }

    #if os(tvOS)
    private func buildMarkers(
        chapters: [DescriptionChapter],
        sponsors: [SponsorSegment],
        totalDuration: Double?
    ) -> [AVTimedMetadataGroup] {
        struct Marker { let title: String; let start: Double; let end: Double }
        var markers: [Marker] = []

        // Chapters from description: end is the next chapter's start (or duration).
        for (i, ch) in chapters.enumerated() {
            let end: Double = {
                if i + 1 < chapters.count { return chapters[i + 1].seconds }
                return totalDuration ?? (ch.seconds + 1)
            }()
            guard end > ch.seconds else { continue }
            markers.append(Marker(title: ch.title, start: ch.seconds, end: end))
        }

        // Sponsor segments inserted as their own markers.
        for s in sponsors {
            markers.append(Marker(title: "Sponsor", start: s.start, end: s.end))
        }

        markers.sort { $0.start < $1.start }

        return markers.map { m in
            let titleItem = AVMutableMetadataItem()
            titleItem.identifier = .commonIdentifierTitle
            titleItem.value = m.title as NSString
            titleItem.extendedLanguageTag = "und"

            let timeRange = CMTimeRangeFromTimeToTime(
                start: CMTime(seconds: m.start, preferredTimescale: 600),
                end: CMTime(seconds: m.end, preferredTimescale: 600)
            )
            return AVTimedMetadataGroup(items: [titleItem], timeRange: timeRange)
        }
    }
    #endif

    // MARK: - Persistence
    func persistCurrentTime() {
        // Avoid saving while we're in the middle of switching videos
        if isSetting { return }
        guard let player = player, let videoId = currentVideo?.id else { return }
        let seconds = player.currentTime().seconds
        guard seconds.isFinite, seconds > 0 else { return }
        store.setWatchProgress(videoId: videoId, progress: seconds)
    }
}
