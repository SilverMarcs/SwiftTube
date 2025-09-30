import SwiftUI
import YouTubePlayerKit
import SwiftMediaViewer

struct PersistentVideoPlayerOverlay: View {
    @Environment(VideoManager.self) var manager
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        if let video = manager.currentVideo, let player = manager.player {
            YouTubePlayerView(player) { state in
                // An optional overlay view for the current state of the player
                switch state {
                case .idle:
                    ProgressView()
                case .ready:
                    EmptyView()
                case .error(_):
                    ContentUnavailableView {
                        Label("Error", systemImage: "exclamationmark.triangle.fill")
                    } description: {
                        Text("YouTube player couldn't be loaded:")
                    } actions: {
                        Button("Retry") {
                            manager.retryCurrentVideo()
                        }
                        .buttonStyle(.borderedProminent)
                    }
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
