import SwiftUI
import YouTubePlayerKit
import SwiftMediaViewer

struct YTPlayerView: View {
    @Environment(VideoManager.self) var manager
    @Environment(\.colorScheme) var colorScheme
    
    @State private var showPlayer = false
    @State private var hasAppeared = false
    
    var body: some View {
        if let player = manager.youTubePlayer {
            YouTubePlayerView(player) { state in
                // An optional overlay view for the current state of the player
                switch state {
                case .idle:
                    ProgressView()
                case .ready:
                    EmptyView()
                case .error(let error):
                    ContentUnavailableView(
                        "Error",
                        systemImage: "exclamationmark.triangle.fill",
                        description: Text("YouTube player couldn't be loaded: \(error.localizedDescription)")
                    )
                }
            }
            .aspectRatio(16/9, contentMode: .fit)
            .background {
                if let video = manager.currentVideo {
                    CachedAsyncImage(url:  URL(string: video.thumbnailURL), targetSize: 500)
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
            .onAppear {
                if hasAppeared {
                    // View reappeared after being hidden, handle potential auto-resume
                    manager.handleViewTransitionComplete()
                }
                hasAppeared = true
            }
            .onDisappear {
                // Prepare for potential view transition
                manager.prepareForViewTransition()
            }
        } else {
            UniversalProgressView()
        }
    }
}
