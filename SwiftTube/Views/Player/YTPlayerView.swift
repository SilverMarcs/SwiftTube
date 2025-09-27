import SwiftUI
import YouTubePlayerKit

struct YTPlayerView: View {
    @Environment(VideoManager.self) var manager
    let namespace: Namespace.ID
    
    var body: some View {
        if let player = manager.youTubePlayer {
            YouTubePlayerKit.YouTubePlayerView(player)
                .navigationTransition(.zoom(sourceID: "MINIPLAYER", in: namespace))
                .aspectRatio(16/9, contentMode: .fit)
                .background(.background)
            
        } else {
            UniversalProgressView()
        }
    }
}
