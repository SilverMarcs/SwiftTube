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
                // On refresh, force fetch rich data for recent 50 videos without it
                await fetchRichDataForced()
            }
            .task {
                if videos.isEmpty {
                    await fetchAllVideos()
                } else {
                    // If videos exist, still check if we need to fetch rich data
                    await fetchRichDataIfNeeded()
                }
            }
        }
    }

    private func fetchAllVideos() async {
        isLoading = true
        defer { isLoading = false }
        
        // First, fetch basic video data from RSS
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
        
        // Then check if we should fetch rich data
        await fetchRichDataIfNeeded()
    }
    
    private func fetchRichDataIfNeeded() async {
        // Get the 50 most recent videos
        let recent50Videos = videos.prefix(50)
        
        // Check how many don't have rich metadata (likeCount is our indicator)
        let videosWithoutRichData = recent50Videos.filter { $0.likeCount == nil }
        
        // Only fetch if at least 5 recent videos don't have rich data
        if videosWithoutRichData.count >= 5 {
            await fetchRichVideoData(for: Array(videosWithoutRichData))
        }
    }
    
    private func fetchRichDataForced() async {
        // Get the 50 most recent videos without rich data
        let recent50Videos = videos.prefix(50)
        let videosWithoutRichData = recent50Videos.filter { $0.likeCount == nil }
        
        if !videosWithoutRichData.isEmpty {
            await fetchRichVideoData(for: Array(videosWithoutRichData))
        }
    }
    
    private func fetchRichVideoData(for videos: [Video]) async {
        guard !videos.isEmpty else { return }
        
        do {
            try await YTService.fetchVideoDetails(for: videos)
            print("Successfully fetched rich data for \(videos.count) videos")
        } catch {
            print("Error fetching video details: \(error)")
        }
    }
}
