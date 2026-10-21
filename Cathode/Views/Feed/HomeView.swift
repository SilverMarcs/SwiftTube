import SwiftUI

struct HomeView: View {
    @Environment(VideoLoader.self) private var videoLoader
    @Environment(YTTVAuthManager.self) private var ytAuth
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
        Group {
            if ytAuth.isSignedIn {
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
                            }
                            .task {
                                if group.id == videoLoader.recommendationRows.last?.id {
                                    await videoLoader.loadMoreRecommendations()
                                }
                            }
                        }
                    }
                    .scenePadding(.bottom)
                }
                #if !os(tvOS)
                .refreshable { await videoLoader.loadRecommendations() }
                #endif
                .overlay {
                    if videoLoader.recommendationRows.isEmpty { UniversalProgressView() }
                }
            } else {
                ContentUnavailableView(
                    "Sign in to YouTube",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: Text("Sign in from Library → Settings to load your feed.")
                )
            }
        }
        .navigationDestination(for: VideoGroup.ID.self) { shelfID in
            ShelfDetailView(shelfID: shelfID)
        }
        .platformTopBar("Feed") {
            if ytAuth.isSignedIn {
                RefreshButton { await videoLoader.loadRecommendations() }
            }
        }
        .iosSettingsToolbarItem()
        .task(id: ytAuth.isSignedIn) {
            if ytAuth.isSignedIn {
                await videoLoader.loadRecommendationsIfNeeded()
            } else {
                videoLoader.clearRecommendations()
            }
        }
    }
}
