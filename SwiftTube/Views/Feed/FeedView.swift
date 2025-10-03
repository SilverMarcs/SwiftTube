// FeedView.swift
import SwiftUI

struct FeedView: View {
    @Environment(UserDefaultsManager.self) private var userDefaults
    @Environment(VideoLoader.self) private var videoLoader
    @State private var showSettings = false

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
            .task {
                // Load videos on launch
                if videos.isEmpty {
                    await videoLoader.loadAllChannelVideos()
                }
            }
            .refreshable {
                await videoLoader.loadAllChannelVideos()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .presentationDetents([.medium])
            }
            .overlay {
                if videos.isEmpty {
                    UniversalProgressView()
                }
            }
        }
    }
}
