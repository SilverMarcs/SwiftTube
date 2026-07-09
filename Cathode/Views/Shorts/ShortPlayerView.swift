import SwiftUI
import AVFoundation

/// Chromeless, auto-looping AVPlayer surface for the shorts feed. Plays the
/// same adaptive HLS stream as regular videos — no transport controls. The
/// player is built when the card becomes active and torn down when it scrolls
/// away, so only the visible short holds a decoder.
struct ShortPlayerView: View {
    let video: Video
    let url: URL
    let isActive: Bool

    @State private var player: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?
    // Reports watch progress so YouTube records the Short as watched and stops
    // re-serving it in recommendations (mirrors VideoManager for regular videos).
    @State private var watchtime = WatchtimeReporter()
    @State private var timeObserver: Any?

    var body: some View {
        PlayerLayerView(player: player)
            .contentShape(Rectangle())
            .onTapGesture { togglePlayback() }
            .onChange(of: isActive, initial: true) { _, active in
                if active { setup() } else { teardown() }
            }
            .onChange(of: url) { _, _ in
                if isActive { setup() }
            }
            .onDisappear { teardown() }
    }

    /// Tap anywhere to toggle play/pause — no on-screen controls.
    private func togglePlayback() {
        guard let player else { return }
        if player.timeControlStatus == .paused {
            player.play()
        } else {
            player.pause()
        }
    }

    private func setup() {
        teardown()
        let queue = AVQueuePlayer()
        // AVPlayerLooper seamlessly re-enqueues the item for gapless looping.
        looper = AVPlayerLooper(player: queue, templateItem: AVPlayerItem(url: url))
        queue.play()

        watchtime.begin(for: video)
        let interval = CMTime(seconds: 1, preferredTimescale: 600)
        let id = video.id
        let reporter = watchtime
        timeObserver = queue.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak queue] _ in
            guard let queue else { return }
            let seconds = queue.currentTime().seconds
            guard seconds.isFinite, seconds > 0, queue.timeControlStatus == .playing else { return }
            reporter.report(videoId: id, position: seconds, isFinal: false)
        }
        player = queue
    }

    private func teardown() {
        if let timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        watchtime.finalize(playerPosition: player?.currentTime().seconds)
        player?.pause()
        looper?.disableLooping()
        looper = nil
        player = nil
    }
}

#if os(macOS)
private struct PlayerLayerView: NSViewRepresentable {
    let player: AVQueuePlayer?

    func makeNSView(context: Context) -> PlayerLayerNSView { PlayerLayerNSView() }

    func updateNSView(_ view: PlayerLayerNSView, context: Context) {
        view.playerLayer.player = player
    }
}

final class PlayerLayerNSView: NSView {
    let playerLayer = AVPlayerLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        playerLayer.videoGravity = .resizeAspectFill
        layer = playerLayer
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
#else
private struct PlayerLayerView: UIViewRepresentable {
    let player: AVQueuePlayer?

    func makeUIView(context: Context) -> PlayerLayerUIView { PlayerLayerUIView() }

    func updateUIView(_ view: PlayerLayerUIView, context: Context) {
        view.playerLayer.player = player
    }
}

final class PlayerLayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        playerLayer.videoGravity = .resizeAspectFill
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
#endif
