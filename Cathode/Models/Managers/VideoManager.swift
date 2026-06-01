//
//  NativeVideoManager.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 15/10/2025.
//

import AVFoundation
import AVKit
import Foundation

@Observable
class VideoManager {
    /// UserDefaults key for the "Always Use Iframe Player" preference.
    static let alwaysUseIframeKey = "alwaysUseIframePlayer"
    private(set) var currentVideo: Video? = nil
    private(set) var player: AVPlayer?

    var isExpanded: Bool = false
    var isSetting: Bool = false
    /// Human-readable error to surface in the player view when stream
    /// resolution fails outright. Cleared at the start of every `setVideo`.
    private(set) var playbackError: String?

    let sponsor = SponsorTracker()
    #if !os(tvOS)
    let iframe = IframePlaybackController()
    #endif

    @ObservationIgnored
    private let watchtime = WatchtimeReporter()

    @ObservationIgnored
    private var timeObserverToken: Any?

    /// Tracks the in-flight `loadVideoStream` task so a rapid second
    /// `setVideo` can cancel the stale one and avoid races where a
    /// late-arriving resolve replaces the newer video's player item.
    @ObservationIgnored
    private var loadingTask: Task<Void, Never>?

    // MARK: - Sponsor passthroughs (kept for call-site stability)
    var sponsorSegments: [SponsorSegment] { sponsor.segments }
    var currentSponsorSegment: SponsorSegment? { sponsor.currentSegment }

    #if !os(tvOS)
    var iframePlayer: YouTubePlayer? { iframe.player }
    var isUsingIframe: Bool { iframe.isActive }
    #else
    var isUsingIframe: Bool { false }
    #endif

    deinit {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
        }
    }

    private func attachPeriodicObserver(to player: AVPlayer) {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        let interval = CMTime(seconds: 1, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            guard let self, let player = self.player else { return }
            let seconds = player.currentTime().seconds
            if seconds.isFinite {
                self.sponsor.refresh(playerSeconds: seconds)
            }
            if let videoId = self.currentVideo?.id,
               seconds.isFinite, seconds > 0, player.timeControlStatus == .playing {
                self.watchtime.report(videoId: videoId, position: seconds, isFinal: false)
            }
        }
    }

    func setVideo(_ video: Video, autoPlay: Bool = true) {
        isExpanded = autoPlay
        persistCurrentTime()

        guard video.id != currentVideo?.id else { return }

        // Cancel any pending load from a previous tap and pause the outgoing
        // player immediately so there's no audio overlap while the new stream
        // resolves. Stream resolution is reliable (iframe fallback covers
        // failures), so the "frozen previous frame on resolve failure"
        // concern that used to gate this is no longer relevant.
        loadingTask?.cancel()
        player?.pause()
        watchtime.finalize(playerPosition: player?.currentTime().seconds)
        isSetting = true

        currentVideo = video
        sponsor.reset()
        playbackError = nil

        #if !os(tvOS)
        tearDownIframe()

        // When the user has opted to always use the iframe player, skip
        // the remote server stream-resolution step entirely.
        if UserDefaults.standard.bool(forKey: Self.alwaysUseIframeKey) {
            isSetting = false
            watchtime.begin(for: video)
            startIframeFallback(for: video, autoPlay: autoPlay)
            return
        }
        #endif

        watchtime.begin(for: video)

        loadingTask = Task { [weak self] in
            await self?.loadVideoStream(for: video, autoPlay: autoPlay)
            if self?.currentVideo?.id == video.id {
                self?.isSetting = false
            }
        }
    }

    private func loadVideoStream(for video: Video, autoPlay: Bool) async {
        await loadVideoStream(for: video, autoPlay: autoPlay, allowCacheRetry: true)
    }

    /// Re-attempts stream resolution for the current video after a playback
    /// error. Re-uses the `setVideo` pipeline but skips its same-id guard so
    /// the user can recover from transient resolve failures without leaving
    /// the player.
    func retryPlayback() {
        guard let video = currentVideo else { return }
        loadingTask?.cancel()
        player?.pause()
        watchtime.finalize(playerPosition: player?.currentTime().seconds)
        isSetting = true
        playbackError = nil
        sponsor.reset()

        #if !os(tvOS)
        tearDownIframe()
        #endif

        watchtime.begin(for: video)

        loadingTask = Task { [weak self] in
            await self?.loadVideoStream(for: video, autoPlay: true)
            if self?.currentVideo?.id == video.id {
                self?.isSetting = false
            }
        }
    }

    /// Called when stream resolution returns nothing. Leaves `currentVideo`
    /// set (so the mini-player still shows the title/thumb) but clears the
    /// AVPlayer and publishes a user-facing error string the player views
    /// render in place of the missing video surface.
    private func surfaceStreamResolutionError(for video: Video) {
        guard currentVideo?.id == video.id else { return }
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        player?.pause()
        player = nil
        playbackError = "This video can't be played right now. YouTube didn't return a playable stream."
        isSetting = false
    }

    func togglePlayPause() {
        #if !os(tvOS)
        if iframe.isActive {
            iframe.togglePlayPause()
            return
        }
        #endif
        guard let player else { return }
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
        }
    }

    /// Whether playback is currently active. Unifies the AVPlayer and iframe
    /// paths for UI affordances like the mini-player play/pause icon.
    var isPlaying: Bool {
        #if !os(tvOS)
        if iframe.isActive { return iframe.isPlaying }
        #endif
        return player?.timeControlStatus == .playing
    }

    // MARK: - Private Methods
    private func resolveStreamWithRetry(id: String, attempts: Int = 2) async -> URL? {
        for attempt in 0..<attempts {
            if Task.isCancelled { return nil }
            if let url = await StreamResolver.resolve(id: id) { return url }
            if attempt < attempts - 1 {
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
        return nil
    }

    private func loadVideoStream(for video: Video, autoPlay: Bool, allowCacheRetry: Bool) async {
        // If the requested video is no longer the current one, abort this task.
        guard currentVideo?.id == video.id, !Task.isCancelled else { return }

        let url: URL
        #if os(iOS)
        if let local = DownloadManager.shared.localURL(for: video.id) {
            url = local
        } else if let streamed = await resolveStreamWithRetry(id: video.id) {
            url = streamed
        } else {
            await MainActor.run { self.surfaceStreamResolutionError(for: video) }
            return
        }
        #else
        if let streamed = await resolveStreamWithRetry(id: video.id) {
            url = streamed
        } else {
            await MainActor.run { self.surfaceStreamResolutionError(for: video) }
            return
        }
        #endif
        if Task.isCancelled { return }

        let playerItem = AVPlayerItem(url: url)
        playerItem.preferredForwardBufferDuration = 30

        // Ensure we're still targeting the same video before mutating the player
        guard currentVideo?.id == video.id, !Task.isCancelled else { return }
        if let existingPlayer = player {
            existingPlayer.pause()
            existingPlayer.replaceCurrentItem(with: playerItem)
        } else {
            let newPlayer = AVPlayer()
            newPlayer.pause()
            newPlayer.replaceCurrentItem(with: playerItem)
            newPlayer.automaticallyWaitsToMinimizeStalling = true
            player = newPlayer
            attachPeriodicObserver(to: newPlayer)
        }

        #if !os(macOS)
        // Set externalMetadata AFTER replaceCurrentItem so AVPlayerViewController
        // observes it as a change on the currentItem (same timing as chapters).
        let externalMeta = await PlayerMetadataBuilder.externalMetadata(for: video)
        guard currentVideo?.id == video.id, !Task.isCancelled else { return }
        playerItem.externalMetadata = externalMeta
        #endif

        let savedProgress = await MainActor.run { LibraryStore.shared.resumeSeconds(for: video) ?? 0 }
        if savedProgress > 5 {
            let time = CMTime(seconds: savedProgress, preferredTimescale: 1)
            guard currentVideo?.id == video.id else { return }
            await player?.seek(to: time)
        }

        if autoPlay {
            player?.play()
        }

        await applyNavigationMarkers(for: video, on: playerItem)

        // If AVPlayer fails to ready up (transient extraction or network glitch), retry once.
        Task { [weak self] in
            let ready = await awaitPlayerItemReady(playerItem)
            guard !ready, allowCacheRetry else { return }
            guard let self else { return }
            guard self.currentVideo?.id == video.id else { return }
            await self.loadVideoStream(for: video, autoPlay: autoPlay, allowCacheRetry: false)
        }
    }

    // MARK: - Navigation Markers (chapters + sponsor segments)
    private func applyNavigationMarkers(for video: Video, on playerItem: AVPlayerItem) async {
        async let descriptionChapters = DescriptionChapterParser.parse(video.description ?? "")
        async let sponsors = SponsorBlockService.fetchSponsorSegments(for: video.id)
        let chapters = await descriptionChapters
        let segments = await sponsors

        guard self.currentVideo?.id == video.id else { return }
        sponsor.update(segments: segments)
        if let seconds = player?.currentTime().seconds, seconds.isFinite {
            sponsor.refresh(playerSeconds: seconds)
        }

        #if os(tvOS)
        let duration = video.duration ?? 0
        let groups = PlayerMetadataBuilder.navigationMarkerGroups(
            chapters: chapters,
            sponsors: segments,
            totalDuration: duration > 0 ? duration : nil
        )
        guard !groups.isEmpty else { return }
        playerItem.navigationMarkerGroups = groups
        #endif
    }

    func skipCurrentSponsorSegment() {
        guard let player, let endSeconds = sponsor.consumeActiveSegmentEnd() else { return }
        player.seek(to: CMTime(seconds: endSeconds, preferredTimescale: 600))
    }

    // MARK: - Persistence

    /// Flushes a final YouTube watchtime segment on state transitions
    /// (play/pause/end) and view lifecycle. YouTube is the source of truth for
    /// resume position — feed/history rows return `Video.watchProgress` which
    /// `LibraryStore.resumeSeconds(for:)` consumes.
    func persistCurrentTime() {
        if isSetting { return }
        guard let videoId = currentVideo?.id else { return }
        let seconds: TimeInterval
        #if !os(tvOS)
        if iframe.isActive {
            seconds = iframe.currentSeconds
        } else if let player {
            seconds = player.currentTime().seconds
        } else {
            return
        }
        #else
        guard let player else { return }
        seconds = player.currentTime().seconds
        #endif
        guard seconds.isFinite, seconds > 0 else { return }
        // Bypass the 5s throttle so the last bit watched before pause/end
        // isn't lost.
        watchtime.report(videoId: videoId, position: seconds, isFinal: true)
    }
}

#if !os(tvOS)
import YouTubePlayerKit

// MARK: - Iframe fallback orchestration

extension VideoManager {
    /// Starts the iframe fallback player. Tears down the AVPlayer first so the
    /// AVPlayer's chrome doesn't linger underneath the WebView.
    fileprivate func startIframeFallback(for video: Video, autoPlay: Bool) {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        player?.pause()
        player = nil

        let resume = LibraryStore.shared.resumeSeconds(for: video) ?? 0
        iframe.start(
            for: video,
            autoPlay: autoPlay,
            resumeSeconds: resume,
            onStateChange: { [weak self] in self?.persistCurrentTime() }
        )
    }

    fileprivate func tearDownIframe() {
        guard iframe.isActive else { return }
        // Persist last known position before destroying the player.
        persistCurrentTime()
        iframe.tearDown()
    }

    func playWithIframe() {
        guard let video = currentVideo else { return }
        loadingTask?.cancel()
        playbackError = nil
        isSetting = false
        startIframeFallback(for: video, autoPlay: true)
    }
}
#endif
