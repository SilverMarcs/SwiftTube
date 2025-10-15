import SwiftUI
import AVKit
import YouTubeKit
import SwiftMediaViewer

struct NativeVideoPlayerView: View {
    @Environment(\.scenePhase) var scenePhase
    @Environment(VideoManager.self) var manager

    var body: some View {
        if let player = manager.player {
            PlatformPlayerContainer(player: player)
                .overlay {
                    if manager.isSetting {
                        UniversalProgressView()
                    }
                }
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
        }
    }
}
