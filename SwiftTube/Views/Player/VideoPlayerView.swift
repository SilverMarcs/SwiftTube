import SwiftUI
import SwiftMediaViewer

struct VideoPlayerView: View {
    @Environment(VideoManager.self) var manager
    @Environment(\.colorScheme) var colorScheme
    
    @Binding var isCustomFullscreen: Bool

    var body: some View {
        if let _ = manager.currentVideo, let player = manager.player {
            YTPlayerView(player: player) {
                Color.clear
                    .contentShape(Rectangle())
                    .overlay(alignment: .center) {
                        Button {
                            Task {
                                await manager.togglePlayPause()
                            }
                        } label: {
                            Image(systemName: manager.isPlaying ? "pause.fill" : "play.fill")
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .controlSize(.extraLarge)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        Button {
                            isCustomFullscreen.toggle()
                        } label: {
                            Image(systemName: isCustomFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .padding()
                    }
            }
            .aspectRatio(16/9, contentMode: .fit)
            .frame(maxWidth: isCustomFullscreen ? .infinity : nil,
                   maxHeight: isCustomFullscreen ? .infinity : nil)
            .ignoresSafeArea(edges: isCustomFullscreen ? .all : [])
        }
    }
}
