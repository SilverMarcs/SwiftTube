import SwiftUI
import AVKit
import YouTubeKit
import SwiftMediaViewer

struct NativeVideoPlayerView: View {
    @Environment(\.scenePhase) var scenePhase
    @Environment(NativeVideoManager.self) var manager

    var body: some View {
        if let player = manager.player {
            PlatformPlayerContainer(player: player)
//                .onChange(of: manager.isFullScreen) {
//                    print("fullscreen", manager.isFullScreen)
//                    if manager.isFullScreen {
//                        OrientationManager.shared.lockOrientation(.landscape, andRotateTo: .landscapeRight)
//                    } else {
//                        OrientationManager.shared.lockOrientation(.all)
//                    }
//                }
                .aspectRatio(16/9, contentMode: .fit)
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
