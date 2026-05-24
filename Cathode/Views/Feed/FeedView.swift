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
            videos: videoLoader.videos,
            onReachEnd: {
                Task { await videoLoader.loadMore() }
            },
            onRefresh: {
                await videoLoader.loadAllChannelVideos()
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
        .platformTopBar("Feed") {
            RefreshButton { await videoLoader.loadAllChannelVideos() }
        }
    }
}
