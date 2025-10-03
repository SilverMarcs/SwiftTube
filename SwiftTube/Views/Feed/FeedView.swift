import SwiftUI
import SwiftMediaViewer

struct FeedView: View {
    @Environment(VideoLoader.self) private var videoLoader
    var authmanager = GoogleAuthManager.shared
    
    private var videos: [Video] {
        videoLoader.videos.filter { !$0.isShort }
    }
    
    var body: some View {
        NavigationStack {
            VideoGridView(videos: videos)
                .navigationTitle("Feed")
                .toolbarTitleDisplayMode(.inlineLarge)
                .refreshable {
                    await videoLoader.loadAllChannelVideos()
                }
                .toolbar {
                    #if os(macOS)
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            Task {
                                await videoLoader.loadAllChannelVideos()
                            }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .keyboardShortcut("r")
                    }
                    #else
                    ToolbarItem(placement: .primaryAction) {
                        CachedAsyncImage(url: URL(string: authmanager.avatarUrl), targetSize: 100)
                            .frame(width: 30, height: 30)
                    }
                    .sharedBackgroundVisibility(.hidden)
                    #endif
                }
        }
    }
}
