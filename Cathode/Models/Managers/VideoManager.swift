//
//  VideoManager.swift
//  Cathode
//

import AVFoundation
import AVKit
import Foundation

@MainActor
@Observable
final class VideoManager {
    private(set) var currentVideo: Video?
    private(set) var player: AVPlayer?

    var isExpanded = false
    var showUpNext = false

    private var playbackSession: PlaybackSession?

    var isSetting: Bool {
        playbackSession?.phase.isLoading ?? false
    }

    var playbackError: String? {
        guard case .failed(let failure) = playbackSession?.phase else { return nil }
        return failure.errorDescription
    }

    private(set) var upNextVideos: [Video] = []
    private(set) var isLoadingUpNext = false

    let sponsor = SponsorTracker()

    @ObservationIgnored
    private let watchtime = WatchtimeReporter()

    @ObservationIgnored
    private var loadingTask: Task<Void, Never>?

    @ObservationIgnored
    private var installationWatchdogTask: Task<Void, Never>?

    @ObservationIgnored
    private var loadWasInterruptedByBackground = false

    @ObservationIgnored
    private var isAppInBackground = false

    @ObservationIgnored
    private var manifestServerRecoverySessionID: UUID?

    @ObservationIgnored
    private var manifestBackedItemNeedsRecovery = false

    @ObservationIgnored
    private var upNextTask: Task<Void, Never>?

    @ObservationIgnored
    private var timeObserverToken: Any?

    @ObservationIgnored
    private var endObserver: NSObjectProtocol?

    @ObservationIgnored
    private var statusObservation: NSKeyValueObservation?

    @ObservationIgnored
    private var failObserver: NSObjectProtocol?

    @ObservationIgnored
    private var timeJumpObserver: NSObjectProtocol?

    var sponsorSegments: [SponsorSegment] { sponsor.segments }
    var currentSponsorSegment: SponsorSegment? { sponsor.currentSegment }

    isolated deinit {
        loadingTask?.cancel()
        installationWatchdogTask?.cancel()
        upNextTask?.cancel()
        if let timeObserverToken {
            player?.removeTimeObserver(timeObserverToken)
        }
        removeEndObserver()
        removeHealthObservers()
    }

    // MARK: - Player observation

    private func attachPeriodicObserver(to player: AVPlayer) {
        if let timeObserverToken {
            self.player?.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }

        let interval = CMTime(seconds: 1, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handlePeriodicPlaybackUpdate()
            }
        }
    }

    private func handlePeriodicPlaybackUpdate() {
        guard let player,
              let item = player.currentItem,
              item.status == .readyToPlay,
              var session = playbackSession,
              session.videoID == currentVideo?.id,
              case .ready = session.phase
        else { return }

        let seconds = player.currentTime().seconds
        guard seconds.isFinite else { return }
        session.position.recordStablePosition(seconds)
        sponsor.refresh(playerSeconds: seconds)

        if player.rate > 0 {
            // AVPlayer can be waiting with a non-zero requested rate. Preserve
            // that play intent so a failure during buffering resumes playing.
            session.intent = .playing
        }

        switch player.timeControlStatus {
        case .playing:
            session.intent = .playing
            session.recovery.recordStablePlayback()
            if seconds > 0 {
                watchtime.report(videoId: session.videoID, position: seconds, isFinal: false)
            }
        case .paused:
            session.intent = .paused
            session.recovery.pauseStabilityClock()
        case .waitingToPlayAtSpecifiedRate:
            session.recovery.pauseStabilityClock()
        @unknown default:
            session.recovery.pauseStabilityClock()
        }

        playbackSession = session
    }

    private func observeItemEnd(_ item: AVPlayerItem) {
        removeEndObserver()
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handlePlaybackEnded()
            }
        }
    }

    private func removeEndObserver() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
    }

    private func observeItemHealth(
        _ item: AVPlayerItem,
        for video: Video,
        token: PlaybackLoadToken
    ) {
        removeHealthObservers()
        playbackSession?.recovery.prepareForReplacementItem()

        statusObservation = item.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch item.status {
                case .readyToPlay:
                    self.handleItemReady(item, token: token)
                case .failed:
                    self.handleItemFailure(item, for: video, token: token)
                default:
                    break
                }
            }
        }

        failObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleItemFailure(item, for: video, token: token)
            }
        }

        timeJumpObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemTimeJumped,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.handleTimeJump(item, token: token)
            }
        }
    }

    private func removeHealthObservers() {
        statusObservation?.invalidate()
        statusObservation = nil
        if let failObserver {
            NotificationCenter.default.removeObserver(failObserver)
            self.failObserver = nil
        }
        if let timeJumpObserver {
            NotificationCenter.default.removeObserver(timeJumpObserver)
            self.timeJumpObserver = nil
        }
    }

    private func handleItemReady(_ item: AVPlayerItem, token: PlaybackLoadToken) {
        guard player?.currentItem === item,
              var session = playbackSession,
              session.matches(token)
        else { return }

        session.markItemReady()
        playbackSession = session
        stopInstallationWatchdogIfReady(session)

        if case .ready = session.phase {
            if session.intent == .playing {
                player?.play()
            } else {
                player?.pause()
            }
        }
    }

    private func handleTimeJump(_ item: AVPlayerItem, token: PlaybackLoadToken) async {
        // Failure handling also invalidates the load token. Waiting briefly
        // prevents AVPlayer's failed-segment rollback from masquerading as a
        // user seek while still recording genuine native-control seeks.
        try? await Task.sleep(for: .milliseconds(100))
        guard item.status == .readyToPlay,
              player?.currentItem === item,
              var session = playbackSession,
              session.matches(token)
        else { return }

        session.position.recordStablePosition(item.currentTime().seconds)
        playbackSession = session
    }

    private func handleItemFailure(
        _ item: AVPlayerItem,
        for video: Video,
        token: PlaybackLoadToken
    ) {
        guard player?.currentItem === item,
              var session = playbackSession,
              session.matches(token),
              session.videoID == video.id
        else { return }

        session.recovery.pauseStabilityClock()
        let source = session.source
        let failedSourceKind = source?.kind
        let failureDetails = Self.playbackFailureDetails(for: item)
        print("Playback failed for \(video.id) using \(String(describing: failedSourceKind)): \(failureDetails)")

        // The proxy listener is expected to disappear while suspended. Keep
        // the current item and source intact until activation has a chance to
        // restore the same localhost port. A failed item will be replaced only
        // after that transparent restoration attempt finishes.
        if source?.dependsOnManifestServer == true,
           isAppInBackground || manifestServerRecoverySessionID == session.id {
            manifestBackedItemNeedsRecovery = true
            playbackSession = session
            return
        }

        // A fatal player notification is not evidence that a fresh signed URL
        // expired. Replacing a healthy item here caused mid-video reloads and
        // quality changes after one transient transport failure. Automatically
        // re-resolve only when the URL is actually at its expiry boundary or
        // when the item depends on Cathode's proxy transport.
        let sourceNeedsRefresh = session.source?.expiresAt.map {
            Date().addingTimeInterval(5 * 60) >= $0
        } ?? false
        guard sourceNeedsRefresh || source?.dependsOnManifestServer == true,
              let attempt = session.recovery.consumeAutomaticRecovery()
        else {
            playbackSession = session
            surfacePlaybackFailure(
                .player(item.error?.localizedDescription),
                for: video,
                sessionID: token.sessionID
            )
            return
        }

        playbackSession = session
        manifestBackedItemNeedsRecovery = false
        player?.pause()
        startLoading(
            video,
            reason: .automaticRecovery(attempt: attempt),
            freshness: .revalidate,
            bypassLocalFile: failedSourceKind == .local,
            requiredRemoteKind: requiredRemoteKind(for: source)
        )
    }

    private func handlePlaybackEnded() {
        persistCurrentTime()
        #if !os(tvOS)
        guard !upNextVideos.isEmpty else { return }
        showUpNext = true
        #endif
    }

    // MARK: - Selection and recovery

    func setVideo(_ video: Video, autoPlay: Bool = true) {
        isExpanded = autoPlay
        persistCurrentTime()
        guard video.id != currentVideo?.id else { return }

        loadWasInterruptedByBackground = false
        manifestBackedItemNeedsRecovery = false
        loadingTask?.cancel()
        player?.pause()
        watchtime.finalize(playerPosition: player?.currentTime().seconds)

        currentVideo = video
        playbackSession = PlaybackSession(videoID: video.id, autoPlay: autoPlay)
        sponsor.reset()
        fetchUpNext(for: video)
        watchtime.begin(for: video)

        startLoading(video, reason: .initial, freshness: .standard)
    }

    func retryPlayback() {
        guard let video = currentVideo,
              var session = playbackSession
        else { return }

        recordCurrentPositionIfHealthy(in: &session)
        loadWasInterruptedByBackground = false
        manifestBackedItemNeedsRecovery = false
        session.intent = .playing
        session.recovery.reset()
        playbackSession = session

        player?.pause()
        watchtime.finalize(playerPosition: player?.currentTime().seconds)
        sponsor.reset()
        showUpNext = false
        watchtime.begin(for: video)

        startLoading(video, reason: .manualRetry, freshness: .revalidate)
    }

    func restorePlaybackAfterActivation() {
        isAppInBackground = false
        if let session = playbackSession,
           session.source?.dependsOnManifestServer == true {
            // Claim this session synchronously. AVFoundation can deliver a
            // failure before the asynchronous listener check starts.
            guard manifestServerRecoverySessionID != session.id else { return }
            manifestServerRecoverySessionID = session.id
        }
        Task { @MainActor [weak self] in
            await self?.restorePlaybackAfterActivationIfNeeded()
        }
    }

    private func restorePlaybackAfterActivationIfNeeded() async {
        guard let video = currentVideo,
              let session = playbackSession
        else { return }

        if session.phase.isLoading, loadWasInterruptedByBackground {
            clearManifestServerRecovery(for: session.id)
            loadWasInterruptedByBackground = false
            startLoading(
                video,
                reason: .foregroundRecovery,
                freshness: .revalidate,
                requiredRemoteKind: requiredRemoteKind(for: session.source)
            )
            return
        }
        loadWasInterruptedByBackground = false

        guard let player,
              case .ready = session.phase,
              let source = session.source
        else {
            clearManifestServerRecovery(for: session.id)
            return
        }

        let sessionID = session.id
        let sourceIsExpiring = source.expiresAt.map {
            Date().addingTimeInterval(5 * 60) >= $0
        } ?? false
        let isPaused = player.timeControlStatus == .paused && player.rate == 0
        let manifestIsAvailable: Bool
        if source.dependsOnManifestServer {
            manifestServerRecoverySessionID = sessionID
            manifestIsAvailable = await HLSManifestService.shared.restoreIfNeeded(at: source.url)
            clearManifestServerRecovery(for: sessionID)
        } else {
            manifestIsAvailable = true
        }

        guard !isAppInBackground,
              currentVideo?.id == video.id,
              self.player === player,
              var currentSession = playbackSession,
              currentSession.id == sessionID,
              case .ready = currentSession.phase
        else { return }

        let itemNeedsRecovery = manifestBackedItemNeedsRecovery
            || player.currentItem?.status == .failed
        manifestBackedItemNeedsRecovery = false

        // Same-port restoration keeps a healthy installed item alive. Only a
        // failed item or an unavailable original port needs the expensive
        // extraction and AVPlayerItem replacement path.
        if source.dependsOnManifestServer,
           manifestIsAvailable,
           !itemNeedsRecovery {
            if sourceIsExpiring && isPaused {
                recordCurrentPositionIfHealthy(in: &currentSession)
                currentSession.recovery.reset()
                playbackSession = currentSession
                player.pause()
                startLoading(
                    video,
                    reason: .expirationRefresh,
                    freshness: .revalidate,
                    requiredRemoteKind: requiredRemoteKind(for: source)
                )
                return
            }
            if currentSession.intent == .playing {
                player.play()
            }
            return
        }

        guard !manifestIsAvailable || itemNeedsRecovery || (sourceIsExpiring && isPaused) else {
            return
        }

        recordCurrentPositionIfHealthy(in: &currentSession)
        currentSession.recovery.reset()
        playbackSession = currentSession
        player.pause()

        startLoading(
            video,
            reason: !manifestIsAvailable || itemNeedsRecovery
                ? .manifestRecovery
                : .expirationRefresh,
            freshness: .revalidate,
            requiredRemoteKind: requiredRemoteKind(for: source)
        )
    }

    private func clearManifestServerRecovery(for sessionID: UUID) {
        guard manifestServerRecoverySessionID == sessionID else { return }
        manifestServerRecoverySessionID = nil
    }

    /// Suspended network and AVFoundation operations aren't safe to continue as
    /// if no time passed. Cancel only an in-flight load; a healthy ready item is
    /// left untouched and checked cheaply when the scene becomes active again.
    func prepareForBackground() {
        isAppInBackground = true
        persistCurrentTime()
        guard playbackSession?.phase.isLoading == true else { return }
        loadWasInterruptedByBackground = true
        loadingTask?.cancel()
        installationWatchdogTask?.cancel()
        installationWatchdogTask = nil
    }

    private func startLoading(
        _ video: Video,
        reason: PlaybackSession.LoadReason,
        freshness: StreamResolver.Freshness,
        bypassLocalFile: Bool = false,
        requiredRemoteKind: PlaybackSource.Kind? = nil
    ) {
        loadingTask?.cancel()
        installationWatchdogTask?.cancel()
        installationWatchdogTask = nil
        manifestServerRecoverySessionID = nil
        manifestBackedItemNeedsRecovery = false
        guard var session = playbackSession,
              session.videoID == video.id
        else { return }

        let token = session.beginLoad(reason: reason)
        playbackSession = session

        loadingTask = Task { [weak self] in
            guard let self else { return }
            await self.loadVideoStream(
                for: video,
                token: token,
                reason: reason,
                freshness: freshness,
                bypassLocalFile: bypassLocalFile,
                requiredRemoteKind: requiredRemoteKind
            )
            guard self.playbackSession?.matches(token) == true else { return }
            self.loadingTask = nil
        }
    }

    private func loadVideoStream(
        for video: Video,
        token: PlaybackLoadToken,
        reason: PlaybackSession.LoadReason,
        freshness: StreamResolver.Freshness,
        bypassLocalFile: Bool,
        requiredRemoteKind: PlaybackSource.Kind?
    ) async {
        guard isCurrent(token), !Task.isCancelled else { return }
        let plannedResumeAt = resumePosition(for: video)

        let source: PlaybackSource
        #if os(iOS)
        if !bypassLocalFile,
           let localURL = DownloadManager.shared.localURL(for: video.id) {
            source = .local(url: localURL)
        } else {
            do {
                source = try await StreamResolver.shared.resolvePlaybackSource(
                    videoID: video.id,
                    freshness: freshness,
                    requiring: requiredRemoteKind
                )
            } catch let error as StreamResolutionError {
                guard !Task.isCancelled, isCurrent(token), !Self.isCancellation(error) else { return }
                surfacePlaybackFailure(.stream(error), for: video, sessionID: token.sessionID)
                return
            } catch {
                guard !Task.isCancelled, isCurrent(token) else { return }
                surfacePlaybackFailure(
                    .stream(.extraction(.network(String(describing: error)))),
                    for: video,
                    sessionID: token.sessionID
                )
                return
            }
        }
        #else
        do {
            source = try await StreamResolver.shared.resolvePlaybackSource(
                videoID: video.id,
                freshness: freshness,
                requiring: requiredRemoteKind
            )
        } catch let error as StreamResolutionError {
            guard !Task.isCancelled, isCurrent(token), !Self.isCancellation(error) else { return }
            surfacePlaybackFailure(.stream(error), for: video, sessionID: token.sessionID)
            return
        } catch {
            guard !Task.isCancelled, isCurrent(token) else { return }
            surfacePlaybackFailure(
                .stream(.extraction(.network(String(describing: error)))),
                for: video,
                sessionID: token.sessionID
            )
            return
        }
        #endif

        guard !Task.isCancelled,
              var session = playbackSession,
              session.matches(token)
        else { return }

        session.phase = .installing(reason)
        session.source = source
        playbackSession = session

        let playerItem: AVPlayerItem
        if let httpUserAgent = source.httpUserAgent {
            let asset = AVURLAsset(
                url: source.url,
                options: [AVURLAssetHTTPUserAgentKey: httpUserAgent]
            )
            playerItem = AVPlayerItem(asset: asset)
        } else {
            playerItem = AVPlayerItem(url: source.url)
        }
        playerItem.preferredForwardBufferDuration = 30
        observeItemEnd(playerItem)
        observeItemHealth(playerItem, for: video, token: token)

        guard !Task.isCancelled, isCurrent(token) else { return }
        if let existingPlayer = player {
            existingPlayer.pause()
            existingPlayer.replaceCurrentItem(with: playerItem)
        } else {
            let newPlayer = AVPlayer(playerItem: playerItem)
            newPlayer.pause()
            newPlayer.automaticallyWaitsToMinimizeStalling = true
            player = newPlayer
            attachPeriodicObserver(to: newPlayer)
        }
        startInstallationWatchdog(
            for: playerItem,
            video: video,
            token: token,
            reason: reason
        )

        #if !os(macOS)
        let externalMetadata = await PlayerMetadataBuilder.externalMetadata(for: video)
        guard !Task.isCancelled,
              isCurrent(token),
              player?.currentItem === playerItem
        else { return }
        playerItem.externalMetadata = externalMetadata
        #endif

        await applyPreferredAudioSelection(
            to: playerItem,
            source: source,
            token: token
        )

        if let resumeAt = plannedResumeAt {
            let time = CMTime(seconds: resumeAt, preferredTimescale: 600)
            guard !Task.isCancelled,
                  isCurrent(token),
                  player?.currentItem === playerItem
            else { return }
            await player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
            guard !Task.isCancelled,
                  isCurrent(token),
                  player?.currentItem === playerItem
            else { return }
            playbackSession?.position.recordStablePosition(resumeAt)
        }

        guard let intent = playbackSession?.intent,
              isCurrent(token),
              player?.currentItem === playerItem
        else { return }
        if intent == .playing {
            player?.play()
        } else {
            player?.pause()
        }

        guard var installedSession = playbackSession,
              installedSession.matches(token)
        else { return }
        installedSession.markInstallationCompleted()
        playbackSession = installedSession
        stopInstallationWatchdogIfReady(installedSession)

        await applyNavigationMarkers(for: video, on: playerItem, token: token)
    }

    private func startInstallationWatchdog(
        for item: AVPlayerItem,
        video: Video,
        token: PlaybackLoadToken,
        reason: PlaybackSession.LoadReason
    ) {
        installationWatchdogTask?.cancel()
        installationWatchdogTask = Task { @MainActor [weak self, weak item] in
            do {
                try await Task.sleep(for: .seconds(30))
            } catch {
                return
            }
            guard let self, let item else { return }
            self.handleInstallationTimeout(
                for: item,
                video: video,
                token: token,
                reason: reason
            )
        }
    }

    private func stopInstallationWatchdogIfReady(_ session: PlaybackSession) {
        guard case .ready = session.phase else { return }
        installationWatchdogTask?.cancel()
        installationWatchdogTask = nil
    }

    private func handleInstallationTimeout(
        for item: AVPlayerItem,
        video: Video,
        token: PlaybackLoadToken,
        reason: PlaybackSession.LoadReason
    ) {
        guard player?.currentItem === item,
              let session = playbackSession,
              session.matches(token),
              case .installing = session.phase
        else { return }

        if case .installationRecovery = reason {
            loadingTask?.cancel()
            surfacePlaybackFailure(
                .player("The video took too long to become ready."),
                for: video,
                sessionID: token.sessionID
            )
            return
        }

        startLoading(
            video,
            reason: .installationRecovery,
            freshness: .revalidate,
            bypassLocalFile: session.source?.kind == .local,
            requiredRemoteKind: requiredRemoteKind(for: session.source)
        )
    }

    private func requiredRemoteKind(for source: PlaybackSource?) -> PlaybackSource.Kind? {
        guard let source else { return nil }
        return switch source.kind {
        case .adaptiveHLS: .adaptiveHLS
        case .nativeHLS where source.dependsOnManifestServer: .nativeHLS
        default: nil
        }
    }

    private func applyPreferredAudioSelection(
        to item: AVPlayerItem,
        source: PlaybackSource,
        token: PlaybackLoadToken
    ) async {
        guard source.kind == .nativeHLS else { return }
        let group = try? await item.asset.loadMediaSelectionGroup(for: .audible)

        guard let group, group.options.count > 1 else { return }

        guard let preferredOption = group.options.max(by: {
                  Self.audioPreference(for: $0) < Self.audioPreference(for: $1)
              }),
              !Task.isCancelled,
              isCurrent(token),
              player?.currentItem === item
        else { return }

        player?.appliesMediaSelectionCriteriaAutomatically = false
        item.select(preferredOption, in: group)
    }

    private static func audioPreference(for option: AVMediaSelectionOption) -> Int {
        let name = option.displayName
        let isOriginal = option.hasMediaCharacteristic(.isOriginalContent)
            || name.localizedStandardContains("original")
        if isOriginal { return 4 }

        let languageTag = (option.extendedLanguageTag ?? option.locale?.identifier ?? "")
            .lowercased()
        let isEnglish = languageTag == "en"
            || languageTag.hasPrefix("en-")
            || languageTag.hasPrefix("en_")
        let isDubbed = option.hasMediaCharacteristic(.dubbedTranslation)
            || option.hasMediaCharacteristic(.voiceOverTranslation)
            || name.localizedStandardContains("dubbed")
        if isEnglish && !isDubbed { return 3 }
        if isEnglish { return 2 }
        return isDubbed ? 0 : 1
    }

    private func resumePosition(for video: Video) -> Double? {
        if let trackedPosition = playbackSession?.position.seconds,
           trackedPosition > 0.25 {
            // Session recovery should preserve even an early playhead. The
            // five-second threshold only applies to persisted history resume.
            return trackedPosition
        }
        let savedPosition = LibraryStore.shared.resumeSeconds(for: video) ?? 0
        return savedPosition > 5 ? savedPosition : nil
    }

    private func surfacePlaybackFailure(
        _ failure: PlaybackFailure,
        for video: Video,
        sessionID: UUID
    ) {
        guard currentVideo?.id == video.id,
              var session = playbackSession,
              session.id == sessionID
        else { return }

        if let timeObserverToken {
            player?.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
        removeEndObserver()
        removeHealthObservers()
        installationWatchdogTask?.cancel()
        installationWatchdogTask = nil
        manifestBackedItemNeedsRecovery = false
        player?.pause()
        watchtime.finalize(playerPosition: session.position.seconds)
        player = nil
        session.source = nil
        session.phase = .failed(failure)
        playbackSession = session
    }

    private static func isCancellation(_ error: StreamResolutionError) -> Bool {
        if case .cancelled = error { return true }
        return false
    }

    private static func playbackFailureDetails(for item: AVPlayerItem) -> String {
        var details: [String] = []
        if let error = item.error as NSError? {
            details.append("error=\(error.domain)/\(error.code) \(error.localizedDescription)")
            if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                details.append(
                    "underlying=\(underlying.domain)/\(underlying.code) \(underlying.localizedDescription)"
                )
            }
        }
        if let events = item.errorLog()?.events, !events.isEmpty {
            let eventDetails = events.suffix(3).map { event in
                "status=\(event.errorStatusCode) domain=\(event.errorDomain) "
                    + "comment=\(event.errorComment ?? "none") uri=\(event.uri ?? "none")"
            }
            details.append(contentsOf: eventDetails)
        }
        return details.isEmpty ? "no AVFoundation error details" : details.joined(separator: " | ")
    }

    private func isCurrent(_ token: PlaybackLoadToken) -> Bool {
        playbackSession?.matches(token) == true && currentVideo?.id == token.videoID
    }

    private func recordCurrentPositionIfHealthy(in session: inout PlaybackSession) {
        guard let item = player?.currentItem,
              item.status == .readyToPlay,
              let seconds = player?.currentTime().seconds
        else { return }
        session.position.recordStablePosition(seconds)
    }

    // MARK: - Playback controls

    func togglePlayPause() {
        guard let player,
              var session = playbackSession
        else { return }

        if player.timeControlStatus == .playing {
            session.intent = .paused
            session.recovery.pauseStabilityClock()
            player.pause()
        } else {
            session.intent = .playing
            player.play()
        }
        playbackSession = session
    }

    var isPlaying: Bool {
        player?.timeControlStatus == .playing
    }

    func skipCurrentSponsorSegment() {
        guard let player,
              let endSeconds = sponsor.consumeActiveSegmentEnd()
        else { return }
        player.seek(to: CMTime(seconds: endSeconds, preferredTimescale: 600))
    }

    // MARK: - Up next and metadata

    private func fetchUpNext(for video: Video) {
        upNextTask?.cancel()
        upNextVideos = []
        showUpNext = false
        isLoadingUpNext = true
        upNextTask = Task { [weak self] in
            guard let self else { return }
            let info = try? await InnerTubeAPI.shared.fetchNextInfo(videoId: video.id)
            guard self.currentVideo?.id == video.id else { return }
            self.upNextVideos = info?.relatedVideos ?? []
            self.isLoadingUpNext = false
        }
    }

    private func applyNavigationMarkers(
        for video: Video,
        on playerItem: AVPlayerItem,
        token: PlaybackLoadToken
    ) async {
        async let descriptionChapters = DescriptionChapterParser.parse(video.description ?? "")
        async let sponsors = SponsorBlockService.fetchSponsorSegments(for: video.id)
        let chapters = await descriptionChapters
        let segments = await sponsors

        guard !Task.isCancelled,
              isCurrent(token),
              player?.currentItem === playerItem
        else { return }

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

    // MARK: - Persistence

    func persistCurrentTime() {
        guard !isSetting,
              let videoID = currentVideo?.id,
              let player,
              let item = player.currentItem,
              item.status == .readyToPlay
        else { return }

        let seconds = player.currentTime().seconds
        guard seconds.isFinite, seconds > 0 else { return }
        playbackSession?.position.recordStablePosition(seconds)
        watchtime.report(videoId: videoID, position: seconds, isFinal: true)
    }
}
