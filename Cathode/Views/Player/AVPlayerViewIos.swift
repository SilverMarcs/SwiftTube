import SwiftUI
import AVKit

struct AVPlayerViewIos: View {
    @Environment(VideoManager.self) var manager
    @Environment(VideoLoader.self) private var videoLoader

    private var upNextBinding: Binding<Bool> {
        Binding(get: { manager.showUpNext }, set: { manager.showUpNext = $0 })
    }

    var body: some View {
        Group {
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
            } else if let player = manager.player {
                AVPlayerIos(player: player)
                    .task(id: player.timeControlStatus) {
                        manager.persistCurrentTime()
                    }
                    .onDisappear {
                        manager.persistCurrentTime()
                    }
            } else {
                Color.black
            }
        }
        .aspectRatio(16/9, contentMode: .fit)
        .overlay {
            SponsorSkipOverlay()
        }
        .overlay {
            if manager.isSetting {
                UniversalProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.black)
                    .environment(\.colorScheme, .dark)
            }
        }
        .sheet(isPresented: upNextBinding) {
            UpNextSheet()
        }
    }
}
