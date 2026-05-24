#if !os(tvOS)
import Combine
import Foundation
import YouTubePlayerKit

/// Owns the iframe-based YouTube player used as a fallback when InnerTube
/// stream resolution fails (IP block, age-gated, restricted). The WebView IS
/// the playback engine — on iOS the SwiftUI view rendering it must stay in the
/// hierarchy for playback to continue.
@Observable
final class IframePlaybackController {
    private(set) var player: YouTubePlayer?
    private(set) var playbackState: YouTubePlayer.PlaybackState?
    private(set) var currentSeconds: TimeInterval = 0

    @ObservationIgnored
    private var subscriptions: Set<AnyCancellable> = []

    var isActive: Bool { player != nil }
    var isPlaying: Bool { playbackState == .playing }

    /// Starts the iframe player for a video. Hosts the resume position in the
    /// player parameters and wires up subscriptions for position tracking and
    /// state-change persistence.
    ///
    /// `onStateChange` fires on every playback-state transition *after* the
    /// first (skipping the initial state so we don't double-persist).
    func start(
        for video: Video,
        autoPlay: Bool,
        resumeSeconds: TimeInterval,
        onStateChange: @escaping () -> Void
    ) {
        let startTime: Measurement<UnitDuration>? = resumeSeconds > 5
            ? .init(value: resumeSeconds, unit: .seconds)
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

        player = yt
        currentSeconds = resumeSeconds

        yt.currentTimePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] measurement in
                self?.currentSeconds = measurement.converted(to: .seconds).value
            }
            .store(in: &subscriptions)

        yt.playbackStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                let firstStateOfSession = self.playbackState == nil
                self.playbackState = state
                if !firstStateOfSession {
                    onStateChange()
                }
            }
            .store(in: &subscriptions)
    }

    /// Tears down the player. Caller should persist position via `currentSeconds`
    /// before calling — once we cancel subscriptions and drop the player we lose
    /// access to its playhead.
    func tearDown() {
        guard player != nil else { return }
        subscriptions.forEach { $0.cancel() }
        subscriptions.removeAll()
        player = nil
        playbackState = nil
        currentSeconds = 0
    }

    /// Toggles play/pause. No-op if no iframe player is active.
    func togglePlayPause() {
        guard let player else { return }
        Task { @MainActor in
            let state = try? await player.getPlaybackState()
            if state == .playing {
                try? await player.pause()
            } else {
                try? await player.play()
            }
        }
    }
}
#endif
