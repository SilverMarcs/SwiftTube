import SwiftUI
import SwiftMediaViewer

struct FeedView: View {
    @Environment(UserDefaultsManager.self) private var userDefaults
    @Environment(VideoLoader.self) private var videoLoader
    var authmanager = GoogleAuthManager.shared
    
    private var videos: [Video] {
        videoLoader.videos.filter { !$0.isShort }
    }
    
    // Grid configuration for macOS
    #if os(macOS)
    private let gridColumns: [GridItem] = [
        GridItem(.adaptive(minimum: 280, maximum: 420), spacing: 16, alignment: .top)
    ]
    #endif
    
    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Feed")
                .toolbarTitleDisplayMode(.inlineLarge)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        CachedAsyncImage(url: URL(string: authmanager.avatarUrl), targetSize: 100)
                            .frame(width: 30, height: 30)
                    }
                    .sharedBackgroundVisibility(.hidden)
                }
                .overlay {
                    if videos.isEmpty {
                        UniversalProgressView()
                    }
                }
        }
    }
    
    @ViewBuilder
    private var content: some View {
        #if os(macOS)
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 16) {
                ForEach(videos) { video in
                    VideoCard(video: video)
                        .contextMenu {
                            watchLaterMenu(for: video)
                            Section {
                                ShareLink(item: URL(string: video.url)!) {
                                    Label("Share Video", systemImage: "square.and.arrow.up")
                                }
                            }
                        }
                }
            }
            .padding(16)
        }
        // Pull-to-refresh isn't native on macOS; keep explicit refresh if desired
        .refreshable {
            await videoLoader.loadAllChannelVideos()
        }
        #else
        List(videos) { video in
            VideoCard(video: video)
                .listRowSeparator(.hidden)
                .listRowInsets(.vertical, 5)
                .listRowInsets(.horizontal, 10)
                .contextMenu {
                    watchLaterMenu(for: video)
                    Section {
                        ShareLink(item: URL(string: video.url)!) {
                            Label("Share Video", systemImage: "square.and.arrow.up")
                        }
                    }
                }
        }
        .listStyle(.plain)
        .refreshable {
            await videoLoader.loadAllChannelVideos()
        }
        #endif
    }
    
    @ViewBuilder
    private func watchLaterMenu(for video: Video) -> some View {
        Button {
            userDefaults.toggleWatchLater(video.id)
        } label: {
            Label(
                userDefaults.isWatchLater(video.id) ? "Remove from Watch Later" : "Add to Watch Later",
                systemImage: userDefaults.isWatchLater(video.id) ? "bookmark.fill" : "bookmark"
            )
        }
    }
}
