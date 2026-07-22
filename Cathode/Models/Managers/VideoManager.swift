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
    private(set) var currentVideo: Video? = nil
    private(set) var player: AVPlayer?

    var isExpanded: Bool = false
    var isSetting: Bool = false
    /// Human-readable error to surface in the player view when stream
    /// resolution fails outright. Cleared at the start of every `setVideo`.
    private(set) var playbackError: String?

    /// Related "up next" videos for the current video, from InnerTube's `/next`
    /// endpoint. Powers the tvOS content proposal + Related tab and the
    /// iOS/macOS end-of-video sheet. Empty until the async fetch resolves.
    private(set) var upNextVideos: [Video] = []

    /// True while the `/next` related-videos fetch is in flight, so the tvOS
    /// Related tab can show a spinner instead of an empty state during load.
    private(set) var isLoadingUpNext = false

    /// Set true when the current item plays to its end (iOS/macOS only) so the
    /// up-next sheet presents. tvOS uses the native `AVContentProposal` instead,
    /// so this stays false there.
    var showUpNext: Bool = false

    let sponsor = SponsorTracker()

    @ObservationIgnored
    private let watchtime = WatchtimeReporter()

    @ObservationIgnored
    private var timeObserverToken: Any?

    /// Tracks the in-flight `loadVideoStream` task so a rapid second
    /// `setVideo` can cancel the stale one and avoid races where a
    /// late-arriving resolve replaces the newer video's player item.
    @ObservationIgnored
    private var loadingTask: Task<Void, Never>?

    /// In-flight `/next` related-videos fetch, cancelled on each `setVideo`.
    @ObservationIgnored
    private var upNextTask: Task<Void, Never>?

    /// When the current player item's googlevideo URLs stop being servable
    /// (from `StreamResolver.Resolved.expiresAt`). Nil for local downloads,
    /// which never expire. `refreshExpiredStream()` consults this on scene
    /// activation.
    @ObservationIgnored
    private var streamExpiresAt: Date?

    /// `AVPlayerItemDidPlayToEndTime` observer for the current item, used to
    /// surface the up-next overlay when a video finishes.
    @ObservationIgnored
    private var endObserver: NSObjectProtocol?

    /// KVO on the current item's `status`, driving the item-health watcher
    /// (`observeItemHealth`). Replaced whenever a new item installs.
    @ObservationIgnored
    private var statusObservation: NSKeyValueObservation?

    /// `AVPlayerItemFailedToPlayToEndTime` observer for the current item —
    /// mid-play fatal errors don't always flip `status` to `.failed`, so both
    /// signals route into `handleItemFailure`.
    @ObservationIgnored
    private var failObserver: NSObjectProtocol?

    /// Armed when the current item first reaches `.readyToPlay`; a later
    /// failure consumes it for one automatic in-place reload. A failure while
    /// disarmed (never got ready, or the reload itself died) surfaces the
    /// error instead, so a dead network can't spin an infinite resolve loop.
    @ObservationIgnored
    private var autoReloadArmed = false

    /// The item whose failure was already handled. `.failed` KVO and
    /// FailedToPlayToEndTime can both fire for one death; the second callback
    /// must not re-enter `handleItemFailure` and clobber the in-flight reload.
    @ObservationIgnored
    private var handledFailureItem: AVPlayerItem?

    // MARK: - Sponsor passthroughs (kept for call-site stability)
    var sponsorSegments: [SponsorSegment] { sponsor.segments }
    var currentSponsorSegment: SponsorSegment? { sponsor.currentSegment }

    deinit {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
        }
        removeEndObserver()
        removeHealthObservers()
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

    // MARK: - Up Next

    /// Kicks off the InnerTube `/next` fetch for the given video's related
    /// videos. Cancels any in-flight fetch and clears stale state so the
    /// overlay/proposal never shows the previous video's suggestions.
    private func fetchUpNext(for video: Video) {
        upNextTask?.cancel()
        upNextVideos = []
        showUpNext = false
        isLoadingUpNext = true
        upNextTask = Task { [weak self] in
            guard let self else { return }
            let info = try? await InnerTubeAPI.shared.fetchNextInfo(videoId: video.id)
            await MainActor.run {
                guard self.currentVideo?.id == video.id else { return }
                self.upNextVideos = info?.relatedVideos ?? []
                self.isLoadingUpNext = false
            }
        }
    }

    /// Registers a one-shot end-of-playback observer for `item`, replacing any
    /// previous one. On iOS/macOS this raises the up-next overlay; tvOS relies
    /// on the native content proposal so it only persists the final position.
    private func observeItemEnd(_ item: AVPlayerItem) {
        removeEndObserver()
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.handlePlaybackEnded()
        }
    }

    private func removeEndObserver() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
    }

    // MARK: - Item health

    /// Watches `item` for the rest of its life and reloads the stream in
    /// place when it dies. Wall-clock expiry tracking alone missed items that
    /// die *before* the ~6h googlevideo TTL — media-services reset during a
    /// long suspension, or googlevideo 403ing early after a network hop (the
    /// URLs are IP-locked) — leaving a player that ignored play until app
    /// relaunch (2026-07 "backgrounded a while, current video won't load").
    /// Also subsumes the old one-shot `awaitPlayerItemReady` error check:
    /// a failure before first ready surfaces the resolution error.
    private func observeItemHealth(_ item: AVPlayerItem, for video: Video) {
        removeHealthObservers()
        autoReloadArmed = false
        handledFailureItem = nil
        statusObservation = item.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                switch item.status {
                case .readyToPlay: self.autoReloadArmed = true
                case .failed: self.handleItemFailure(item, for: video)
                default: break
                }
            }
        }
        failObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.handleItemFailure(item, for: video)
        }
    }

    private func removeHealthObservers() {
        statusObservation?.invalidate()
        statusObservation = nil
        if let failObserver {
            NotificationCenter.default.removeObserver(failObserver)
            self.failObserver = nil
        }
    }

    /// One automatic in-place reload when the current item dies after having
    /// been ready, resuming at the local playhead (a `.failed` item still
    /// reports its last `currentTime`). Never autoplays — same conservative
    /// choice as `refreshExpiredStream`.
    private func handleItemFailure(_ item: AVPlayerItem, for video: Video) {
        guard item !== handledFailureItem else { return }
        guard currentVideo?.id == video.id, player?.currentItem === item else { return }
        handledFailureItem = item

        guard autoReloadArmed else {
            surfaceStreamResolutionError(for: video)
            return
        }
        autoReloadArmed = false

        let seconds = player?.currentTime().seconds
        let resumeAt = (seconds?.isFinite == true) ? seconds : nil

        loadingTask?.cancel()
        player?.pause()
        isSetting = true
        playbackError = nil

        loadingTask = Task { [weak self] in
            await self?.loadVideoStream(for: video, autoPlay: false, resumeAt: resumeAt)
            if self?.currentVideo?.id == video.id {
                self?.isSetting = false
            }
        }
    }

    private func handlePlaybackEnded() {
        persistCurrentTime()
        #if !os(tvOS)
        guard !upNextVideos.isEmpty else { return }
        showUpNext = true
        #endif
    }

    func setVideo(_ video: Video, autoPlay: Bool = true) {
        isExpanded = autoPlay
        persistCurrentTime()

        guard video.id != currentVideo?.id else { return }

        // Cancel any pending load from a previous tap and pause the outgoing
        // player immediately so there's no audio overlap while the new stream
        // resolves.
        loadingTask?.cancel()
        player?.pause()
        watchtime.finalize(playerPosition: player?.currentTime().seconds)
        isSetting = true

        currentVideo = video
        sponsor.reset()
        playbackError = nil
        streamExpiresAt = nil
        fetchUpNext(for: video)

        watchtime.begin(for: video)

        loadingTask = Task { [weak self] in
            await self?.loadVideoStream(for: video, autoPlay: autoPlay)
            if self?.currentVideo?.id == video.id {
                self?.isSetting = false
            }
        }
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
        showUpNext = false

        watchtime.begin(for: video)

        loadingTask = Task { [weak self] in
            await self?.loadVideoStream(for: video, autoPlay: true)
            if self?.currentVideo?.id == video.id {
                self?.isSetting = false
            }
        }
    }

    /// Re-resolves the current video's stream in place when its googlevideo
    /// URLs have expired (~6h TTL). Without this, a video left paused across a
    /// long suspension keeps an AVPlayer item that looks ready but 403s on
    /// every byte-range request — play does nothing and the user had to switch
    /// to another video and back to force a refetch. Called on scene
    /// activation; keeps the local playhead and never autoplays. Cheap no-op
    /// while the stream is still fresh.
    func refreshExpiredStream() {
        guard let video = currentVideo,
              player != nil,
              let expiresAt = streamExpiresAt,
              // 5-minute margin so we don't hand back a stream that dies
              // moments after the user presses play.
              Date().addingTimeInterval(5 * 60) >= expiresAt
        else { return }

        let seconds = player?.currentTime().seconds
        let resumeAt = (seconds?.isFinite == true) ? seconds : nil

        loadingTask?.cancel()
        player?.pause()
        isSetting = true
        playbackError = nil

        loadingTask = Task { [weak self] in
            await self?.loadVideoStream(for: video, autoPlay: false, resumeAt: resumeAt)
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
        removeEndObserver()
        removeHealthObservers()
        player?.pause()
        player = nil
        playbackError = "This video can't be played right now. YouTube didn't return a playable stream."
        isSetting = false
    }

    func togglePlayPause() {
        guard let player else { return }
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
        }
    }

    /// Whether playback is currently active, for UI affordances like the
    /// mini-player play/pause icon.
    var isPlaying: Bool {
        player?.timeControlStatus == .playing
    }

    // MARK: - Private Methods
    private func resolveStream(id: String) async -> StreamResolver.Resolved? {
        if Task.isCancelled { return nil }
        return await StreamResolver.resolveRemoteHLS(id: id)
    }

    private func loadVideoStream(for video: Video, autoPlay: Bool, resumeAt: Double? = nil) async {
        // If the requested video is no longer the current one, abort this task.
        guard currentVideo?.id == video.id, !Task.isCancelled else { return }

        let url: URL
        var expiresAt: Date?
        #if os(iOS)
        if let local = DownloadManager.shared.localURL(for: video.id) {
            url = local
        } else if let streamed = await resolveStream(id: video.id) {
            url = streamed.url
            expiresAt = streamed.expiresAt
        } else {
            await MainActor.run { self.surfaceStreamResolutionError(for: video) }
            return
        }
        #else
        if let streamed = await resolveStream(id: video.id) {
            url = streamed.url
            expiresAt = streamed.expiresAt
        } else {
            await MainActor.run { self.surfaceStreamResolutionError(for: video) }
            return
        }
        #endif
        if Task.isCancelled { return }
        streamExpiresAt = expiresAt

        let playerItem = AVPlayerItem(url: url)
        playerItem.preferredForwardBufferDuration = 30
        observeItemEnd(playerItem)
        observeItemHealth(playerItem, for: video)

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

        let savedProgress: Double
        if let resumeAt {
            savedProgress = resumeAt
        } else {
            savedProgress = await MainActor.run { LibraryStore.shared.resumeSeconds(for: video) ?? 0 }
        }
        if savedProgress > 5 {
            let time = CMTime(seconds: savedProgress, preferredTimescale: 1)
            guard currentVideo?.id == video.id else { return }
            await player?.seek(to: time)
        }

        if autoPlay {
            player?.play()
        }

        await applyNavigationMarkers(for: video, on: playerItem)
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
        guard let videoId = currentVideo?.id, let player else { return }
        let seconds = player.currentTime().seconds
        guard seconds.isFinite, seconds > 0 else { return }
        // Bypass the 5s throttle so the last bit watched before pause/end
        // isn't lost.
        watchtime.report(videoId: videoId, position: seconds, isFinal: true)
    }
}
