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

    /// Tracks the in-flight `loadVideoStream` task so a rapid second
    /// `setVideo` can cancel the stale one and avoid races where a
    /// late-arriving resolve replaces the newer video's player item.
    private var loadingTask: Task<Void, Never>?

    // MARK: - Watchtime reporting state
    //
    // Per-session CPN (Client Playback Nonce) and account-bound playback
    // tracking URLs. Pings are fire-and-forget; reportPlaybackStarted runs
    // once when a video begins, then reportWatchtime runs throttled
    // (~5s) and on session end / video change / app background.
    private var watchtimeCPN: String?
    private var watchtimeTrackingURLs: PlaybackTrackingURLs?
    private var watchtimeVideoId: String?
    private var watchtimeSegmentStart: TimeInterval = 0
    private var watchtimeLastPing: Date = .distantPast
    private var watchtimeStarted: Bool = false
    private var watchtimeFetchTask: Task<Void, Never>?
    /// Throttle: report watchtime no more often than this.
    private let watchtimeInterval: TimeInterval = 5

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

        // Flush watchtime for the outgoing session before switching.
        finalizeWatchtimeForCurrentSession()

        // Cancel any pending load from a previous tap so its late-arriving
        // resolve can't clobber this new request. The old player keeps
        // playing until the new playerItem is ready — replaceCurrentItem
        // does the transition atomically. Eager pausing here would leave
        // the user staring at a frozen previous video if the new resolve
        // failed for any reason.
        loadingTask?.cancel()
        isSetting = true

        currentVideo = video
        sponsorSegments = []
        currentSponsorSegment = nil
        store.addToHistory(video)

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
        guard currentVideo?.id == video.id, !Task.isCancelled else { return }

        let t0 = Date()
        let url: URL
        #if os(iOS)
        if let local = DownloadManager.shared.localURL(for: video.id) {
            url = local
        } else if let streamed = await StreamResolver.resolve(id: video.id) {
            url = streamed
        } else {
            print("YouTubeKit error: no playable stream for \(video.id)")
            return
        }
        #else
        if let streamed = await StreamResolver.resolve(id: video.id) {
            url = streamed
        } else {
            print("YouTubeKit error: no playable stream for \(video.id)")
            return
        }
        #endif
        if Task.isCancelled { return }
        let resolveElapsed = Date().timeIntervalSince(t0)

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

        // If AVPlayer fails to ready up (transient extraction or network glitch), retry once.
        Task { [weak self] in
            let ready = await awaitPlayerItemReady(playerItem)
            let readyElapsed = Date().timeIntervalSince(t0)
            let avElapsed = readyElapsed - resolveElapsed
            print(String(
                format: "play %@: resolve %.2fs · avplayer %.2fs · total %.2fs%@",
                video.id, resolveElapsed, avElapsed, readyElapsed,
                ready ? "" : " (FAILED)"
            ))
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
        // Throttled watchtime ping → YouTube watch history server.
        maybeReportWatchtime(videoId: videoId, position: seconds, isFinal: false)
    }

    // MARK: - Watchtime (YouTube watch-history reporting)

    /// Starts a new watchtime session. Generates a CPN and pre-fetches
    /// account-bound tracking URLs. No-op when not signed in.
    private func beginWatchtimeSession(for video: Video) {
        // Reset session state regardless of sign-in so stale URLs from a
        // previous session don't leak across.
        watchtimeFetchTask?.cancel()
        watchtimeFetchTask = nil
        watchtimeCPN = nil
        watchtimeTrackingURLs = nil
        watchtimeVideoId = nil
        watchtimeSegmentStart = 0
        watchtimeLastPing = .distantPast
        watchtimeStarted = false

        guard YTTVAuthManager.shared.isSignedIn else { return }

        let cpn = InnerTubeAPI.generateCPN()
        let videoId = video.id
        watchtimeCPN = cpn
        watchtimeVideoId = videoId

        watchtimeFetchTask = Task { [weak self] in
            let urls = await InnerTubeAPI.shared.fetchAuthenticatedTrackingURLs(videoId: videoId)
            await MainActor.run {
                guard let self else { return }
                guard self.watchtimeVideoId == videoId else { return }
                self.watchtimeTrackingURLs = urls
            }
        }
    }

    /// Sends `videostatsPlaybackUrl` once at the start, then throttled
    /// `videostatsWatchtimeUrl` pings every `watchtimeInterval` seconds.
    /// Pass `isFinal: true` to bypass throttling for a final ping.
    private func maybeReportWatchtime(videoId: String, position: TimeInterval, isFinal: Bool) {
        guard YTTVAuthManager.shared.isSignedIn else { return }
        guard let cpn = watchtimeCPN, watchtimeVideoId == videoId else { return }

        let urls = watchtimeTrackingURLs
        let now = Date()

        if !watchtimeStarted {
            watchtimeStarted = true
            watchtimeSegmentStart = 0
            watchtimeLastPing = now
            Task {
                await InnerTubeAPI.shared.reportPlaybackStarted(videoId: videoId, cpn: cpn, trackingURLs: urls)
            }
            return
        }

        if !isFinal && now.timeIntervalSince(watchtimeLastPing) < watchtimeInterval {
            return
        }

        let segStart = watchtimeSegmentStart
        let segEnd = position
        // Guard against zero-length segments (YouTube ignores st == et).
        guard segEnd > segStart else { return }
        watchtimeSegmentStart = segEnd
        watchtimeLastPing = now
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

    /// Fires a final watchtime ping for the current session (call on app
    /// background or video change). Safe to call when no session is active.
    private func finalizeWatchtimeForCurrentSession() {
        guard let videoId = watchtimeVideoId,
              let player = player else { return }
        let seconds = player.currentTime().seconds
        guard seconds.isFinite, seconds > 0 else { return }
        maybeReportWatchtime(videoId: videoId, position: seconds, isFinal: true)
    }

    /// Public entry point so the app can flush watchtime on background /
    /// scene phase change.
    func flushWatchtime() {
        finalizeWatchtimeForCurrentSession()
    }
}
