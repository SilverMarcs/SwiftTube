import SwiftUI
import AVKit
import YouTubeKit
import SwiftMediaViewer

struct NativeVideoPlayerView: View {
    @Environment(\.scenePhase) var scenePhase
    @Environment(VideoManager.self) var manager

    var body: some View {
        Group {
            if let player = manager.player {
                PlatformPlayerContainer(player: player)
                    .background(.bar)
#if !os(macOS)
                    .onChange(of: scenePhase) {
                        if scenePhase == .active {
                            manager.resumeTimerTracking()
                        } else if scenePhase == .background {
                            manager.pauseTimerTracking()
                        }
                    }
#endif
            } else {
                Color.black
                    .aspectRatio(16/9, contentMode: .fit)
            }
        }
        .overlay {
            if manager.isSetting {
                UniversalProgressView()
            }
        }
    }
}
