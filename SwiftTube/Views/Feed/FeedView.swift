// VideoListView.swift
import SwiftUI
import SwiftData

struct FeedView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Channel.createdAt) private var channels: [Channel]
    @Query(sort: \Video.publishedAt, order: .reverse) private var videos: [Video]
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            List(videos) { video in
                VideoRowView(video: video)
                    .listRowSeparator(.hidden)
                    .listRowInsets(.vertical, 7)
                    .listRowInsets(.horizontal, 10)
            }
            .listStyle(.plain)
            .overlay {
                if isLoading {
                    UniversalProgressView()
                }
            }
            .navigationTitle("Feed")
            .toolbarTitleDisplayMode(.inlineLarge)
            .refreshable {
                await fetchAllVideos()
            }
            .task {
                if !channels.isEmpty && videos.isEmpty {
                    await fetchAllVideos()
                }
            }
        }
    }

    private func fetchAllVideos() async {
        isLoading = true
        defer { isLoading = false }
        
        for channel in channels {
            do {
                let channelVideos = try await FeedParser.fetchChannelVideosFromRSS(channel: channel)
                for video in channelVideos {
                    modelContext.upsertVideo(video)
                }
            } catch {
                print("Error fetching videos for \(channel.title): \(error)")
            }
        }
    }
}
