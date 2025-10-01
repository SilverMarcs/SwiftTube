import SwiftUI
import SwiftMediaViewer

struct PersistentVideoPlayerOverlay: View {
    @Environment(VideoManager.self) var manager
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        if let video = manager.currentVideo, let player = manager.player {
            YTPlayerView(player: player)
                .onChange(of: player.isFullscreen) { exited, entered in
                       if entered {
                           OrientationManager.shared.lockOrientation(.landscape, andRotateTo: .landscapeRight)
                       } else {
                           OrientationManager.shared.lockOrientation(.all)
                       }
                   }
                .aspectRatio(16/9, contentMode: .fit)
                .background {
                    CachedAsyncImage(url: URL(string: video.thumbnailURL), targetSize: 500)
                        .blur(radius: 10)
                        .overlay {
                            if colorScheme == .dark {
                                Color.black.opacity(0.85)
                            } else {
                                Color.white.opacity(0.85)
                            }
                        }
                        .clipped()
                        .ignoresSafeArea()
                }
        }
    }
}
