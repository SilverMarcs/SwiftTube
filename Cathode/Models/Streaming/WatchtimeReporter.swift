import AVFoundation
import Foundation

/// Mirrors YouTube's web-client watchtime ping cadence: one `/api/stats/playback`
/// on start, then `/api/stats/watchtime` every ~5s with `st`/`et` segment params.
/// Tracking URLs are pre-bound to the account server-side so YT records the view.
///
/// No-op when `YTCookieAuth` isn't signed in. The fetch task is fire-and-forget;
/// pings only start firing once account-bound tracking URLs land.
final class WatchtimeReporter {
    private static let segmentInterval: TimeInterval = 5
    /// Forward playhead delta beyond wall delta + this slack counts as a seek.
    private static let seekSlack: TimeInterval = 2

    private var cpn: String?
    private var trackingURLs: PlaybackTrackingURLs?
    private var videoId: String?
    private var segmentStart: TimeInterval = 0
    private var lastPing: Date = .distantPast
    private var playbackStarted: Bool = false
    private var fetchTask: Task<Void, Never>?
    /// Playhead at the most recent observer tick — used to detect seeks by
    /// comparing playhead delta to wall-clock delta between ticks.
    private var lastTickPosition: TimeInterval = 0
    private var lastTickTime: Date = .distantPast

    var activeVideoId: String? { videoId }

    func begin(for video: Video) {
        fetchTask?.cancel()
        fetchTask = nil
        cpn = nil
        trackingURLs = nil
        videoId = nil
        segmentStart = 0
        lastPing = .distantPast
        playbackStarted = false
        lastTickPosition = 0
        lastTickTime = .distantPast

        guard YTCookieAuth.shared.isSignedIn else { return }

        let newCpn = InnerTubeAPI.generateCPN()
        let id = video.id
        cpn = newCpn
        videoId = id

        fetchTask = Task { [weak self] in
            let urls = await InnerTubeAPI.shared.fetchAuthenticatedTrackingURLs(videoId: id)
            await MainActor.run {
                guard let self else { return }
                guard self.videoId == id else { return }
                self.trackingURLs = urls
            }
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
            Task {
                await InnerTubeAPI.shared.reportPlaybackStarted(videoId: reportId, cpn: cpn, trackingURLs: urls)
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
                Task {
                    await InnerTubeAPI.shared.reportWatchtime(
                        videoId: reportId,
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
                    videoId: reportId,
                    cpn: cpn,
                    trackingURLs: urls,
                    segmentStart: landingStart,
                    segmentEnd: landingEnd
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
        Task {
            await InnerTubeAPI.shared.reportWatchtime(
                videoId: reportId,
                cpn: cpn,
                trackingURLs: urls,
                segmentStart: segStart,
                segmentEnd: segEnd
            )
        }
    }

    /// Fires a final watchtime ping for the current session. Call on app
    /// background, video switch, and view dismissal.
    func finalize(playerPosition: TimeInterval?) {
        guard let id = videoId else { return }
        guard let seconds = playerPosition, seconds.isFinite, seconds > 0 else {
            fetchTask?.cancel()
            return
        }
        let pendingFetch = fetchTask
        Task { @MainActor [weak self] in
            await pendingFetch?.value
            self?.report(videoId: id, position: seconds, isFinal: true)
        }
    }
}
