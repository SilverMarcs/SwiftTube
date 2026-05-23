//
//  NativeVideoManager.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 15/10/2025.
//

import AVFoundation
import AVKit
import Combine
import Foundation
#if !os(tvOS)
import YouTubePlayerKit
#endif

@Observable
class VideoManager {
    private(set) var currentVideo: Video? = nil
    private(set) var player: AVPlayer?
    private(set) var sponsorSegments: [SponsorSegment] = []
    private(set) var currentSponsorSegment: SponsorSegment? = nil

    var isExpanded: Bool = false
    var isSetting: Bool = false
    /// Human-readable error to surface in the player view when stream
    /// resolution fails outright. Cleared at the start of every `setVideo`.
    private(set) var playbackError: String?

    private var timeObserverToken: Any?

    /// Tracks the in-flight `loadVideoStream` task so a rapid second
    /// `setVideo` can cancel the stale one and avoid races where a
    /// late-arriving resolve replaces the newer video's player item.
    private var loadingTask: Task<Void, Never>?

    // MARK: - Iframe fallback (iOS + macOS only)
    //
    // When InnerTube stream resolution fails (IP block, age-gated, restricted),
    // we fall back to the YouTube iframe player. The WebView IS the playback
    // engine — on iOS the SwiftUI view rendering it must stay in the hierarchy
    // for playback to continue.
    #if !os(tvOS)
    private(set) var iframePlayer: YouTubePlayer?
    private(set) var iframePlaybackState: YouTubePlayer.PlaybackState?
    private var iframeCurrentSeconds: TimeInterval = 0
    private var iframeSubscriptions: Set<AnyCancellable> = []
    #endif

    // MARK: - YouTube watchtime session (AVPlayer path only)
    //
    // When the user has cookie auth enabled, we mirror YouTube's web client
    // ping cadence: one /api/stats/playback on start, then /api/stats/watchtime
    // every ~5s with `st`/`et` segment params. Tracking URLs are pre-bound to
    // the account server-side so YT records the view in the user's history.
    //
    // The iframe path doesn't use this — its embedded WebView is logged in
    // (shared cookie jar) and reports on its own.
    private var watchCPN: String?
    private var watchTrackingURLs: PlaybackTrackingURLs?
    private var watchVideoId: String?
    private var watchSegmentStart: TimeInterval = 0
    private var watchLastPing: Date = .distantPast
    private var watchPlaybackStarted: Bool = false
    private var watchFetchTask: Task<Void, Never>?
    /// Playhead at the most recent observer tick — used to detect seeks by
    /// comparing playhead delta to wall-clock delta between ticks.
    private var watchLastTickPosition: TimeInterval = 0
    private var watchLastTickTime: Date = .distantPast
    private static let watchSegmentInterval: TimeInterval = 5
    /// Forward playhead delta beyond wall delta + this slack counts as a seek.
    private static let watchSeekSlack: TimeInterval = 2

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
            guard let self else { return }
            self.refreshSponsorState()
            if let videoId = self.currentVideo?.id, let player = self.player {
                let seconds = player.currentTime().seconds
                if seconds.isFinite, seconds > 0, player.timeControlStatus == .playing {
                    self.maybeReportWatchtime(videoId: videoId, position: seconds, isFinal: false)
                }
            }
        }
    }

    func setVideo(_ video: Video, autoPlay: Bool = true) {
        isExpanded = autoPlay
        persistCurrentTime()

        guard video.id != currentVideo?.id else {
            return
        }

        // Cancel any pending load from a previous tap and pause the outgoing
        // player immediately so there's no audio overlap while the new stream
        // resolves. Stream resolution is reliable (iframe fallback covers
        // failures), so the "frozen previous frame on resolve failure"
        // concern that used to gate this is no longer relevant.
        loadingTask?.cancel()
        player?.pause()
        finalizeWatchtimeSession()
        isSetting = true

        currentVideo = video
        sponsorSegments = []
        currentSponsorSegment = nil
        playbackError = nil

        #if !os(tvOS)
        tearDownIframe()
        #endif

        beginWatchtimeSession(for: video)

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
        finalizeWatchtimeSession()
        isSetting = true
        playbackError = nil
        sponsorSegments = []
        currentSponsorSegment = nil

        #if !os(tvOS)
        tearDownIframe()
        #endif

        beginWatchtimeSession(for: video)

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
        if let iframePlayer {
            Task { @MainActor in
                let state = try? await iframePlayer.getPlaybackState()
                if state == .playing {
                    try? await iframePlayer.pause()
                } else {
                    try? await iframePlayer.play()
                }
            }
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
        if iframePlayer != nil {
            return iframePlaybackState == .playing
        }
        #endif
        return player?.timeControlStatus == .playing
    }

    // MARK: - Private Methods
    private func loadVideoStream(for video: Video, autoPlay: Bool, allowCacheRetry: Bool) async {
        // If the requested video is no longer the current one, abort this task.
        guard currentVideo?.id == video.id, !Task.isCancelled else { return }

        let url: URL
        #if os(iOS)
        if let local = DownloadManager.shared.localURL(for: video.id) {
            url = local
        } else if let streamed = await StreamResolver.resolve(id: video.id) {
            url = streamed
        } else {
            await MainActor.run { self.surfaceStreamResolutionError(for: video) }
            return
        }
        #else
        if let streamed = await StreamResolver.resolve(id: video.id) {
            url = streamed
        } else {
            await MainActor.run { self.surfaceStreamResolutionError(for: video) }
            return
        }
        #endif
        if Task.isCancelled { return }

        let playerItem = AVPlayerItem(url: url)
        #if !os(macOS)
        playerItem.externalMetadata = await createMetadataItems(for: video)
        #endif

        // Ensure we're still targeting the same video before mutating the player
        guard currentVideo?.id == video.id, !Task.isCancelled else { return }
        if let existingPlayer = player {
            existingPlayer.replaceCurrentItem(with: playerItem)
        } else {
            let newPlayer = AVPlayer(playerItem: playerItem)
            player = newPlayer
            attachPeriodicObserver(to: newPlayer)
        }

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
        artistItem.value = video.channelTitle as NSString
        artistItem.extendedLanguageTag = "und"
        metadata.append(artistItem)

        // Description
        if let description = video.description, !description.isEmpty {
            let descItem = AVMutableMetadataItem()
            descItem.identifier = .commonIdentifierDescription
            descItem.value = description as NSString
            descItem.extendedLanguageTag = "und"
            metadata.append(descItem)
        }

        // Artwork (thumbnail)
        if let url = video.thumbnailURL {
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
        async let descriptionChapters = DescriptionChapterParser.parse(video.description ?? "")
        async let sponsors = SponsorBlockService.fetchSponsorSegments(for: video.id)
        let chapters = await descriptionChapters
        let segments = await sponsors

        guard self.currentVideo?.id == video.id else { return }
        self.sponsorSegments = segments
        refreshSponsorState()

        #if os(tvOS)
        let duration = video.duration ?? 0
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

    /// Flushes a final YouTube watchtime segment on state transitions
    /// (play/pause/end) and view lifecycle. YouTube is the source of truth for
    /// resume position — feed/history rows return `Video.watchProgress` which
    /// `LibraryStore.resumeSeconds(for:)` consumes.
    func persistCurrentTime() {
        if isSetting { return }
        guard let videoId = currentVideo?.id else { return }
        let seconds: TimeInterval
        #if !os(tvOS)
        if iframePlayer != nil {
            seconds = iframeCurrentSeconds
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
        maybeReportWatchtime(videoId: videoId, position: seconds, isFinal: true)
    }
}

// MARK: - YouTube watchtime session (AVPlayer path)
//
// No-op when YTCookieAuth isn't signed in. The fetch task is fire-and-forget;
// pings only start firing once account-bound tracking URLs land.

extension VideoManager {
    fileprivate func beginWatchtimeSession(for video: Video) {
        watchFetchTask?.cancel()
        watchFetchTask = nil
        watchCPN = nil
        watchTrackingURLs = nil
        watchVideoId = nil
        watchSegmentStart = 0
        watchLastPing = .distantPast
        watchPlaybackStarted = false
        watchLastTickPosition = 0
        watchLastTickTime = .distantPast

        guard YTCookieAuth.shared.isSignedIn else { return }

        let cpn = InnerTubeAPI.generateCPN()
        let videoId = video.id
        watchCPN = cpn
        watchVideoId = videoId

        watchFetchTask = Task { [weak self] in
            let urls = await InnerTubeAPI.shared.fetchAuthenticatedTrackingURLs(videoId: videoId)
            await MainActor.run {
                guard let self else { return }
                guard self.watchVideoId == videoId else { return }
                self.watchTrackingURLs = urls
            }
        }
    }

    fileprivate func maybeReportWatchtime(videoId: String, position: TimeInterval, isFinal: Bool) {
        guard let cpn = watchCPN, watchVideoId == videoId else { return }
        guard let urls = watchTrackingURLs else { return }

        let now = Date()

        if !watchPlaybackStarted {
            watchPlaybackStarted = true
            // Start the first segment at the current playhead — not 0 — so
            // we don't claim to have watched the lead-in for resumed videos.
            watchSegmentStart = position
            watchLastPing = now
            watchLastTickPosition = position
            watchLastTickTime = now
            Task {
                await InnerTubeAPI.shared.reportPlaybackStarted(videoId: videoId, cpn: cpn, trackingURLs: urls)
            }
            return
        }

        // Seek detection: when the playhead delta between ticks doesn't match
        // wall-clock delta, the user scrubbed. Close the current segment at
        // the last honest position and start fresh from where they landed.
        let wallDelta = now.timeIntervalSince(watchLastTickTime)
        let playDelta = position - watchLastTickPosition
        let seeked = playDelta < -0.5 || playDelta > wallDelta + Self.watchSeekSlack

        if seeked {
            // 1. Close out the segment we were watching at the pre-seek position
            //    so YouTube credits the time we actually watched.
            let closeStart = watchSegmentStart
            let closeEnd = watchLastTickPosition
            if closeEnd > closeStart {
                Task {
                    await InnerTubeAPI.shared.reportWatchtime(
                        videoId: videoId,
                        cpn: cpn,
                        trackingURLs: urls,
                        segmentStart: closeStart,
                        segmentEnd: closeEnd
                    )
                }
            }
            // 2. Immediately ping the new playhead so progress / "resume from"
            //    advances to the seek destination. Without this the next
            //    progress update would wait for the 5s throttle, which is
            //    typically longer than the user takes to scrub again — so
            //    history reflects scrub N-1 when they're already on scrub N.
            let landingStart = position
            let landingEnd = position + 0.001
            Task {
                await InnerTubeAPI.shared.reportWatchtime(
                    videoId: videoId,
                    cpn: cpn,
                    trackingURLs: urls,
                    segmentStart: landingStart,
                    segmentEnd: landingEnd
                )
            }
            watchSegmentStart = landingEnd
            watchLastPing = now
            watchLastTickPosition = position
            watchLastTickTime = now
            return
        }

        watchLastTickPosition = position
        watchLastTickTime = now

        if !isFinal, now.timeIntervalSince(watchLastPing) < Self.watchSegmentInterval { return }

        let segStart = watchSegmentStart
        let segEnd = position
        guard segEnd > segStart else { return }
        watchSegmentStart = segEnd
        watchLastPing = now
        Task {
            await InnerTubeAPI.shared.reportWatchtime(
                videoId: videoId,
                cpn: cpn,
                trackingURLs: urls,
                segmentStart: segStart,
                segmentEnd: segEnd
            )
        }
    }

    /// Fires a final watchtime ping for the current session — call on app
    /// background, video switch, and view dismissal.
    fileprivate func finalizeWatchtimeSession() {
        guard let videoId = watchVideoId else { return }
        let seconds: TimeInterval? = {
            if let player { return player.currentTime().seconds }
            return nil
        }()
        guard let seconds, seconds.isFinite, seconds > 0 else {
            watchFetchTask?.cancel()
            return
        }
        let pendingFetch = watchFetchTask
        Task { @MainActor [weak self] in
            await pendingFetch?.value
            guard let self else { return }
            self.maybeReportWatchtime(videoId: videoId, position: seconds, isFinal: true)
        }
    }
}

#if !os(tvOS)
// MARK: - Iframe fallback

extension VideoManager {
    /// Starts the iframe fallback player. Tears down the AVPlayer, creates a
    /// YouTubePlayer with the resume position baked into parameters, and wires
    /// up subscriptions for position tracking + state-change persistence.
    fileprivate func startIframeFallback(for video: Video, autoPlay: Bool) {
        // Tear down AVPlayer.
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        player?.pause()
        player = nil

        let resume = LibraryStore.shared.resumeSeconds(for: video) ?? 0
        let startTime: Measurement<UnitDuration>? = resume > 5
            ? .init(value: resume, unit: .seconds)
            : nil

        let parameters = YouTubePlayer.Parameters(
            autoPlay: autoPlay,
            startTime: startTime
        )
        let configuration = YouTubePlayer.Configuration(
            allowsInlineMediaPlayback: true,
            allowsAirPlayForMediaPlayback: true,
            allowsPictureInPictureMediaPlayback: true
        )
        let yt = YouTubePlayer(
            source: .video(id: video.id),
            parameters: parameters,
            configuration: configuration
        )

        iframePlayer = yt
        iframeCurrentSeconds = resume

        // Track current time for resume persistence.
        yt.currentTimePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] measurement in
                self?.iframeCurrentSeconds = measurement.converted(to: .seconds).value
            }
            .store(in: &iframeSubscriptions)

        // Track playback state for the mini-player icon and persist on every
        // transition — matches the AVPlayer pattern where
        // .task(id: timeControlStatus) drives persistence.
        yt.playbackStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                let firstStateOfSession = self.iframePlaybackState == nil
                self.iframePlaybackState = state
                if !firstStateOfSession {
                    self.persistCurrentTime()
                }
            }
            .store(in: &iframeSubscriptions)
    }

    fileprivate func tearDownIframe() {
        guard iframePlayer != nil else { return }
        // Persist last known position before destroying the player.
        persistCurrentTime()
        iframeSubscriptions.forEach { $0.cancel() }
        iframeSubscriptions.removeAll()
        iframePlayer = nil
        iframePlaybackState = nil
        iframeCurrentSeconds = 0
    }
}
#endif
