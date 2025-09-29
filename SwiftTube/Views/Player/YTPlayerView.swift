import SwiftUI
import YouTubePlayerKit

struct YTPlayerView: View {
    @Environment(VideoManager.self) var manager
    
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
            .background(.background)
        } else {
            UniversalProgressView()
        }
    }
}
