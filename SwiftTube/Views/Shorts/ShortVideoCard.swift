import SwiftUI

struct ShortVideoCard: View {
    let video: Video
    let isActive: Bool
    let shortsManager: ShortsManager
    
    @State private var showDetail: Bool = false
    
    var body: some View {
        VStack {
            if let player = shortsManager.player, isActive, shortsManager.isPlaying(video) {
                YTPlayerView(player: player)
                    .overlay {
                        switch player.state {
                        case .idle:
                            ProgressView().controlSize(.large)
                        case .ready:
                            EmptyView()
                        case .error(_):
                            ContentUnavailableView {
                                Label("Error", systemImage: "exclamationmark.triangle.fill")
                            } description: {
                                Text("YouTube player couldn't be loaded")
                            } actions: {
                                Button("Retry") {
                                    shortsManager.retryCurrentVideo()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                    .aspectRatio(9/16, contentMode: .fit)
                    .clipped()
                    .sheet(isPresented: $showDetail) {
                        VideoDetailView(video: video)
                            .presentationDetents([.medium])
                            .presentationBackground(.bar)
                    }
            }
        }
    }
}
