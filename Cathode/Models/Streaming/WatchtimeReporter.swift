import AVFoundation
import Foundation
import OSLog

/// Mirrors YouTube's web-client watchtime ping cadence: one `/api/stats/playback`
/// on start, then `/api/stats/watchtime` every ~5s with `st`/`et` segment params.
/// Tracking URLs are pre-bound to the account server-side so YT records the view.
///
/// No-op when cookie authentication cannot be refreshed. The fetch task is
/// fire-and-forget; pings only start once account-bound tracking URLs land.
final class WatchtimeReporter {
    private static let segmentInterval: TimeInterval = 5
    private static let maximumNetworkAttempts = 3
    private static let logger = Logger(
        subsystem: "com.SilverMarcs.SwiftTube",
        category: "Watchtime"
    )
    /// Forward playhead delta beyond wall delta + this slack counts as a seek.
    private static let seekSlack: TimeInterval = 2

    private var cpn: String?
    private var trackingURLs: PlaybackTrackingURLs?
    private var videoId: String?
    private var segmentStart: TimeInterval = 0
    private var lastPing: Date = .distantPast
    private var playbackStarted: Bool = false
    private var fetchTask: Task<PlaybackTrackingURLs?, Never>?
    private var sessionID: UUID?
    private var lastFinalizedPosition: TimeInterval?
    private var sessionStartedAt: Date = .distantPast
    /// Playhead at the most recent observer tick — used to detect seeks by
    /// comparing playhead delta to wall-clock delta between ticks.
    private var lastTickPosition: TimeInterval = 0
    private var lastTickTime: Date = .distantPast

    var activeVideoId: String? { videoId }

    func begin(for video: Video) {
        // Do not cancel the previous fetch here. A final watchtime snapshot may
        // still be awaiting its tracking URLs after the app is foregrounded.
        // Session IDs prevent that old result from mutating this new session.
        fetchTask = nil
        let newSessionID = UUID()
        sessionID = newSessionID
        cpn = nil
        trackingURLs = nil
        videoId = nil
        segmentStart = 0
        lastPing = .distantPast
        playbackStarted = false
        sessionStartedAt = .distantPast
        lastTickPosition = 0
        lastTickTime = .distantPast
        lastFinalizedPosition = nil

        let newCpn = InnerTubeAPI.generateCPN()
        let id = video.id
        cpn = newCpn
        videoId = id
        sessionStartedAt = Date()

        let task = Task {
            // Cookie bootstrap is asynchronous at launch. Refresh here instead
            // of permanently disabling reporting when playback wins that race.
            await YTCookieAuth.shared.refreshSignInState()
            return await Self.fetchTrackingURLs(videoId: id)
        }
        fetchTask = task
        Task { @MainActor [weak self] in
            let urls = await task.value
            guard let self,
                  self.sessionID == newSessionID,
                  self.videoId == id
            else { return }
            self.trackingURLs = urls
        }
    }

    func report(videoId reportId: String, position: TimeInterval, isFinal: Bool) {
        guard let cpn, videoId == reportId else { return }
        guard let urls = trackingURLs else { return }

        let now = Date()

        if !playbackStarted {
            playbackStarted = true
            // Start the first segment at the current playhead — not 0 — so
            // we don't claim to have watched the lead-in for resumed videos.
            segmentStart = position
            lastPing = now
            lastTickPosition = position
            lastTickTime = now
            let runtime = max(0, now.timeIntervalSince(sessionStartedAt))
            Task {
                await Self.reportPlaybackStarted(
                    videoId: reportId,
                    cpn: cpn,
                    trackingURLs: urls,
                    runtime: runtime
                )
            }
            return
        }

        // Seek detection: when the playhead delta between ticks doesn't match
        // wall-clock delta, the user scrubbed. Close the current segment at
        // the last honest position and start fresh from where they landed.
        let wallDelta = now.timeIntervalSince(lastTickTime)
        let playDelta = position - lastTickPosition
        let seeked = playDelta < -0.5 || playDelta > wallDelta + Self.seekSlack

        if seeked {
            // 1. Close out the segment we were watching at the pre-seek position
            //    so YouTube credits the time we actually watched.
            let closeStart = segmentStart
            let closeEnd = lastTickPosition
            if closeEnd > closeStart {
                let runtime = max(0, now.timeIntervalSince(sessionStartedAt))
                Task {
                    await Self.reportWatchtime(
                        videoId: reportId,
                        cpn: cpn,
                        trackingURLs: urls,
                        segmentStart: closeStart,
                        segmentEnd: closeEnd,
                        runtime: runtime
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
            let runtime = max(0, now.timeIntervalSince(sessionStartedAt))
            Task {
                await Self.reportWatchtime(
                    videoId: reportId,
                    cpn: cpn,
                    trackingURLs: urls,
                    segmentStart: landingStart,
                    segmentEnd: landingEnd,
                    runtime: runtime
                )
            }
            segmentStart = landingEnd
            lastPing = now
            lastTickPosition = position
            lastTickTime = now
            return
        }

        lastTickPosition = position
        lastTickTime = now

        if !isFinal, now.timeIntervalSince(lastPing) < Self.segmentInterval { return }

        let segStart = segmentStart
        let segEnd = position
        guard segEnd > segStart else { return }
        segmentStart = segEnd
        lastPing = now
        let runtime = max(0, now.timeIntervalSince(sessionStartedAt))
        Task {
            await Self.reportWatchtime(
                videoId: reportId,
                cpn: cpn,
                trackingURLs: urls,
                segmentStart: segStart,
                segmentEnd: segEnd,
                runtime: runtime
            )
        }
    }

    private static func fetchTrackingURLs(videoId: String) async -> PlaybackTrackingURLs? {
        for attempt in 0..<maximumNetworkAttempts {
            if Task.isCancelled { return nil }
            if let urls = await InnerTubeAPI.shared.fetchAuthenticatedTrackingURLs(videoId: videoId) {
                return urls
            }
            if attempt + 1 < maximumNetworkAttempts {
                try? await Task.sleep(for: .milliseconds(400 * (attempt + 1)))
            }
        }
        logger.error("Unable to obtain watchtime tracking URLs")
        return nil
    }

    private static func reportPlaybackStarted(
        videoId: String,
        cpn: String,
        trackingURLs: PlaybackTrackingURLs,
        runtime: TimeInterval
    ) async {
        for attempt in 0..<maximumNetworkAttempts {
            if await InnerTubeAPI.shared.reportPlaybackStarted(
                videoId: videoId,
                cpn: cpn,
                trackingURLs: trackingURLs,
                runtime: runtime
            ) {
                return
            }
            if attempt + 1 < maximumNetworkAttempts {
                await YTCookieAuth.shared.refreshSignInState()
                try? await Task.sleep(for: .milliseconds(400 * (attempt + 1)))
            }
        }
        logger.error("Playback-start reporting failed after retries")
    }

    private static func reportWatchtime(
        videoId: String,
        cpn: String,
        trackingURLs: PlaybackTrackingURLs,
        segmentStart: TimeInterval,
        segmentEnd: TimeInterval,
        runtime: TimeInterval
    ) async {
        for attempt in 0..<maximumNetworkAttempts {
            if await InnerTubeAPI.shared.reportWatchtime(
                videoId: videoId,
                cpn: cpn,
                trackingURLs: trackingURLs,
                segmentStart: segmentStart,
                segmentEnd: segmentEnd,
                runtime: runtime
            ) {
                return
            }
            if attempt + 1 < maximumNetworkAttempts {
                await YTCookieAuth.shared.refreshSignInState()
                try? await Task.sleep(for: .milliseconds(400 * (attempt + 1)))
            }
        }
        logger.error("Watchtime reporting failed after retries")
    }

    /// Fires a final watchtime ping for the current session. Call on app
    /// background, video switch, and view dismissal.
    func finalize(playerPosition: TimeInterval?) {
        guard let id = videoId, let cpn else { return }
        guard let seconds = playerPosition, seconds.isFinite, seconds > 0 else {
            fetchTask?.cancel()
            return
        }
        if let lastFinalizedPosition,
           abs(lastFinalizedPosition - seconds) < 0.05 {
            return
        }
        lastFinalizedPosition = seconds

        let resolvedURLs = trackingURLs
        let pendingFetch = fetchTask
        let didStartPlayback = playbackStarted
        let finalSegmentStart = segmentStart
        let runtime = max(0, Date().timeIntervalSince(sessionStartedAt))

        // Advance local segment state synchronously so a later finalization or
        // resumed periodic tick cannot report this same interval twice.
        if playbackStarted {
            segmentStart = max(segmentStart, seconds)
            lastPing = Date()
        }

        Task {
            let urls: PlaybackTrackingURLs?
            if let resolvedURLs {
                urls = resolvedURLs
            } else {
                urls = await pendingFetch?.value
            }
            guard let urls else {
                return
            }
            if !didStartPlayback {
                await Self.reportPlaybackStarted(
                    videoId: id,
                    cpn: cpn,
                    trackingURLs: urls,
                    runtime: runtime
                )
            }

            // If tracking configuration arrived only after playback stopped,
            // report a tiny landing segment at the real playhead. This advances
            // resume progress without claiming the unobserved lead-in.
            let segmentStart = didStartPlayback && seconds > finalSegmentStart
                ? finalSegmentStart
                : seconds
            await Self.reportWatchtime(
                videoId: id,
                cpn: cpn,
                trackingURLs: urls,
                segmentStart: segmentStart,
                segmentEnd: max(seconds, segmentStart + 0.001),
                runtime: runtime
            )
        }
    }
}
