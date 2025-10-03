// FeedView.swift
import SwiftUI
import SwiftMediaViewer

struct FeedView: View {
    @Environment(UserDefaultsManager.self) private var userDefaults
    @Environment(VideoLoader.self) private var videoLoader
    var authmanager = GoogleAuthManager.shared

    private var videos: [Video] {
        videoLoader.videos.filter { !$0.isShort }
    }
    
    var body: some View {
        NavigationStack {
            List(videos) { video in
                VideoCard(video: video)
                    .listRowSeparator(.hidden)
                    .listRowInsets(.vertical, 5)
                    .listRowInsets(.horizontal, 10)
                    .contextMenu {
                        Button {
                            userDefaults.toggleWatchLater(video.id)
                        } label: {
                            Label(
                                userDefaults.isWatchLater(video.id) ? "Remove from Watch Later" : "Add to Watch Later",
                                systemImage: userDefaults.isWatchLater(video.id) ? "bookmark.fill" : "bookmark"
                            )
                        }
                        Section {
                            ShareLink(item: URL(string: video.url)!) {
                                Label("Share Video", systemImage: "square.and.arrow.up")
                            }
                        }
                    }
            }
            .listStyle(.plain)
            .navigationTitle("Feed")
            .toolbarTitleDisplayMode(.inlineLarge)
            .refreshable {
                await videoLoader.loadAllChannelVideos()
            }
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
}
