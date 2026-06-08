import SwiftMediaViewer
import SwiftUI

/// tvOS-only feed that always shows the recommendations feed, independent of
/// `videoLoader.mode`. On iOS/macOS the same feed is reached via the
/// `FeedToolbar` toggle instead; here it lives in its own tab.
struct RecommendationFeedView: View {
    @Environment(VideoLoader.self) private var videoLoader
    @Environment(LibraryStore.self) private var library
    #if os(tvOS)
    @Environment(VideoManager.self) private var videoManager
    #endif

    var body: some View {
        VideoGridView(
            videos: videoLoader.recommendations,
            isGuestAllowed: true,
            onRefresh: {
                await videoLoader.loadRecommendations()
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
        .platformTopBar("Recommended") {
            RefreshButton { await videoLoader.loadRecommendations() }
        }
        .task {
            if videoLoader.recommendations.isEmpty {
                await videoLoader.loadRecommendations()
            }
        }
    }
}
