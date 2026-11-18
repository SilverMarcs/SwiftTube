#if os(iOS)
import AVFoundation
import Observation
import SwiftMediaViewer

@MainActor
@Observable
final class ShortsFeed: SMVVideoFeed {
    private let loader: VideoLoader
    private var nextIndex = 1
    private var activeVideo: Video?
    private var activePlayback = ShortPlaybackModel()

    @ObservationIgnored private let watchtime = WatchtimeReporter()
    @ObservationIgnored private weak var observedPlayer: AVPlayer?
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var statusObservation: NSKeyValueObservation?

    init(loader: VideoLoader) {
        self.loader = loader
    }

    static func item(for video: Video) -> SMVVideoItem {
        SMVVideoItem(id: video.id, thumbnailURL: video.thumbnailURL, title: video.channelTitle)
    }

    func nextVideos() async throws -> [SMVVideoItem] {
        while nextIndex >= loader.shortVideos.count, loader.hasMoreShorts {
            try Task.checkCancellation()
            try await loader.fetchMoreShorts()
        }
        try Task.checkCancellation()
        guard nextIndex < loader.shortVideos.count else { return [] }
        let batch = loader.shortVideos[nextIndex...].map(Self.item(for:))
        nextIndex = loader.shortVideos.count
        return batch
    }

    func playback(for id: String) -> ShortPlaybackModel? {
        activeVideo?.id == id ? activePlayback : nil
    }

    func activate(_ video: Video) async {
        if activeVideo?.id != video.id {
            activePlayback = ShortPlaybackModel()
            activeVideo = video
        }
        if let expiry = activePlayback.source?.expiresAt, expiry <= .now {
            await activePlayback.retry(videoID: video.id)
        } else {
            await activePlayback.resolveIfNeeded(videoID: video.id)
        }
    }

    func playerChanged(id: String, player: AVPlayer?) {
        stopObservingPlayer()
        guard let player, let video = activeVideo, video.id == id,
              let playback = playback(for: id), let source = playback.source else { return }

        observedPlayer = player
        watchtime.begin(for: video)
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 600), queue: .main
        ) { [weak self, weak player] time in
            MainActor.assumeIsolated {
                guard let self, let player, self.observedPlayer === player,
                      time.seconds.isFinite, time.seconds > 0,
                      player.timeControlStatus == .playing else { return }
                self.watchtime.report(videoId: id, position: time.seconds, isFinal: false)
            }
        }

        statusObservation = player.currentItem?.observe(\.status, options: [.initial, .new]) {
            [weak self, weak player, weak playback] item, _ in
            guard item.status == .failed else { return }
            let message = item.error?.localizedDescription ?? "The video stopped playing unexpectedly."
            Task { @MainActor in
                guard let self, let player, self.observedPlayer === player,
                      self.activeVideo?.id == id else { return }
                await playback?.playerFailed(message, source: source, videoID: id)
            }
        }
    }

    private func stopObservingPlayer() {
        statusObservation?.invalidate()
        statusObservation = nil
        if let timeObserver {
            observedPlayer?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        watchtime.finalize(playerPosition: observedPlayer?.currentTime().seconds)
        observedPlayer = nil
    }
}
#endif
