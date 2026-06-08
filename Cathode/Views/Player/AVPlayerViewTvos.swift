import SwiftUI
import AVKit

struct AVPlayerViewTvos: View {
    @Environment(VideoManager.self) private var manager

    var body: some View {
        if let error = manager.playbackError {
            ContentUnavailableView {
                Label("Can't Play This Video", systemImage: "exclamationmark.triangle.fill")
            } description: {
                Text(error)
            } actions: {
                Button("Retry") {
                    manager.retryPlayback()
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)
            .ignoresSafeArea()
        } else if let player = manager.player, let video = manager.currentVideo {
            AVPlayerTvos(player: player, video: video)
                .ignoresSafeArea()
                .overlay {
                    if manager.isSetting {
                        UniversalProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(.black)
                    }
                }
        } else {
            UniversalProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black)
                .ignoresSafeArea()
        }
    }
}
