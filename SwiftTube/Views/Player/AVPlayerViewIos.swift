import SwiftUI

struct AVPlayerViewIos: View {
    @Environment(\.scenePhase) var scenePhase
    @Environment(VideoManager.self) var manager

    var body: some View {
        Group {
            if let player = manager.player {
                AVPlayerIos(player: player)
            } else {
                Color.black
            }
        }
        .onChange(of: scenePhase) {
            manager.persistCurrentTime()
        }
        .onDisappear {
            manager.persistCurrentTime()
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
