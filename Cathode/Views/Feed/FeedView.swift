import SwiftMediaViewer
import SwiftUI

struct FeedView: View {
    @Environment(VideoLoader.self) private var videoLoader
    @Environment(LibraryStore.self) private var library
    #if os(tvOS)
    @Environment(VideoManager.self) private var videoManager
    #endif

    var body: some View {
        VideoGridView(
            videos: videoLoader.currentVideos,
            onReachEnd: {
                guard videoLoader.mode == .subscriptions else { return }
                Task { await videoLoader.loadMore() }
            },
            onRefresh: {
                await videoLoader.refreshCurrent()
            }
        ) {
            #if os(tvOS)
            if let current = videoManager.currentVideo ?? library.history.first {
                Section("Currently Playing") {
                    VideoCard(video: current)
                        .frame(maxWidth: 560)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            #endif
        }
        .platformTopBar(videoLoader.mode == .subscriptions ? "Feed" : "Recommended") {
            FeedToolbar()
        }
    }
}
