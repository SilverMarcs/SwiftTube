import SwiftUI
import AVKit

struct AVPlayerViewIos: View {
    @Environment(VideoManager.self) var manager
    @Environment(VideoLoader.self) private var videoLoader

    var body: some View {
        Group {
            if let player = manager.player {
                AVPlayerIos(player: player)
                    .task(id: player.timeControlStatus) {
                        manager.persistCurrentTime()
                    }
                    .onDisappear {
                        manager.persistCurrentTime()
                    }
                    .task(id: manager.isExpanded) {
                        if !manager.isExpanded {
                            Task { await videoLoader.loadAllChannelVideos(fetchDetails: true) }
                        }
                    }
            } else {
                Color.black
            }
        }
        .aspectRatio(16/9, contentMode: .fit)
        .background(.bar)
        .overlay {
            if manager.isSetting {
                UniversalProgressView()
            }
        }
    }
}
