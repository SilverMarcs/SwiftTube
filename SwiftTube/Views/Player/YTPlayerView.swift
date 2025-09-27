import SwiftUI
import YouTubePlayerKit

struct YTPlayerView: View {
    @Environment(VideoManager.self) var manager
    
    var body: some View {
        if let player = manager.youTubePlayer {
            YouTubePlayerKit.YouTubePlayerView(player)
                .aspectRatio(16/9, contentMode: .fit)
                .background(.background)
        } else {
            UniversalProgressView()
        }
    }
}
