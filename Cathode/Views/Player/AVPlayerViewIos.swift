import SwiftUI
import AVKit
// import YouTubePlayerKit  // re-enable when restoring iframe fallback

struct AVPlayerViewIos: View {
    @Environment(VideoManager.self) var manager
    @Environment(VideoLoader.self) private var videoLoader

    var body: some View {
        Group {
            // Iframe fallback is temporarily disabled — we surface an error view
            // instead so iframe-only videos are visibly broken rather than
            // silently routed to a different playback path. Restore by
            // re-enabling the YouTubePlayerKit import above and uncommenting
            // the branch below.
            //
            // if let iframe = manager.iframePlayer {
            //     YouTubePlayerView(iframe) { state in
            //         switch state {
            //         case .idle:
            //             UniversalProgressView()
            //         case .ready:
            //             EmptyView()
            //         case .error(let error):
            //             ContentUnavailableView(
            //                 "Playback Error",
            //                 systemImage: "exclamationmark.triangle.fill",
            //                 description: Text(error.localizedDescription)
            //             )
            //         }
            //     }
            //     .id(manager.currentVideo?.id ?? "iframe")
            // } else
            if let error = manager.playbackError {
                ContentUnavailableView {
                    Label("Can't Play This Video", systemImage: "exclamationmark.triangle.fill")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") {
                        manager.retryPlayback()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if let player = manager.player {
                AVPlayerIos(player: player)
                    .task(id: player.timeControlStatus) {
                        manager.persistCurrentTime()
                    }
                    .onDisappear {
                        manager.persistCurrentTime()
                    }
            } else {
                Color.black
            }
        }
        .aspectRatio(16/9, contentMode: .fit)
        .overlay {
            SponsorSkipOverlay()
        }
        .overlay {
            if manager.isSetting {
                UniversalProgressView()
                    .background(.black)
            }
        }
    }
}
