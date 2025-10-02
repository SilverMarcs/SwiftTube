// VideoListView.swift
import SwiftUI
import SwiftData

struct FeedView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Video> { $0.isShort == false },
        sort: \Video.publishedAt,
        order: .reverse
    ) private var videos: [Video]
    
    @State private var showSettings = false
    @State private var videoLoader: VideoLoader?
    
    var body: some View {
        NavigationStack {
            List(videos) { video in
                VideoCard(video: video)
                    .listRowSeparator(.hidden)
                    .listRowInsets(.vertical, 5)
                    .listRowInsets(.horizontal, 10)
                    .contextMenu {
                        Button {
                            video.isWatchLater.toggle()
                        } label: {
                            Label(
                                video.isWatchLater ? "Remove from Watch Later" : "Add to Watch Later",
                                systemImage: video.isWatchLater ? "bookmark.fill" : "bookmark"
                            )
                        }
                    }
            }
            .listStyle(.plain)
            .navigationTitle("Feed")
            .toolbarTitleDisplayMode(.inlineLarge)
            .task {
                // Initialize video loader and load videos on launch
                if videoLoader == nil {
                    videoLoader = VideoLoader(modelContainer: modelContext.container)
                    await videoLoader?.loadAllChannelVideos()
                }
            }
            .refreshable {
                await videoLoader?.loadAllChannelVideos()
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
        }
    }
}
