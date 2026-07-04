import SwiftUI

/// Home tab: the recommended feed as titled horizontal shelves (FinStream section
/// paradigm), adapting across iOS/iPadOS/macOS/tvOS. A "currently playing" card
/// sits on top; tapping a shelf header opens the full grid.
struct HomeView: View {
    @Environment(VideoLoader.self) private var videoLoader
    #if os(tvOS)
    @Environment(VideoManager.self) private var videoManager
    @Environment(LibraryStore.self) private var library
    #endif

    private var spacing: CGFloat {
        #if os(tvOS)
        60
        #else
        25
        #endif
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: spacing) {
                #if os(tvOS)
                if let current = videoManager.currentVideo ?? library.history.first {
                    Section("Currently Playing") {
                        VideoCard(video: current)
                            .frame(maxWidth: 560)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                #endif

                ForEach(videoLoader.recommendationRows) { group in
                    VideoShelf(group: group) {
                        Task { await videoLoader.loadMoreInShelf(group.id) }
                    } destination: {
                        ShelfDetailView(shelfID: group.id, title: group.title ?? "Recommended")
                    }
                }
            }
            .scenePadding(.bottom)
        }
        #if !os(tvOS)
        .refreshable { await videoLoader.loadRecommendations() }
        #endif
        .overlay {
            if videoLoader.recommendationRows.isEmpty {
                UniversalProgressView()
            }
        }
        .platformTopBar("Home") {
            RefreshButton { await videoLoader.loadRecommendations() }
        }
        .iosSettingsToolbarItem()
        .task {
            if videoLoader.recommendationRows.isEmpty {
                await videoLoader.loadRecommendations()
            }
        }
    }
}
