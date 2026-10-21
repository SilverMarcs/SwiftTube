import SwiftUI

struct HomeView: View {
    @Environment(VideoLoader.self) private var videoLoader

    var body: some View {
        VideoGridView(
            videos: videoLoader.recommendations,
            isGuestAllowed: true,
            extractsShorts: false,
            onReachEnd: { Task { await videoLoader.loadMoreRecommendations() } },
            onRefresh: { await videoLoader.loadRecommendations() }
        )
        .platformTopBar("Feed") {
            RefreshButton { await videoLoader.loadRecommendations() }
        }
        .task { await videoLoader.loadRecommendationsIfNeeded() }
    }
}
