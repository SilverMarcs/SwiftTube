// VideoListView.swift
import SwiftUI
import SwiftData

struct VideoListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Video.publishedAt, order: .reverse) private var videos: [Video]
    @State private var isLoading = false
    
    var body: some View {
        List(videos) { video in
            VideoRowView(video: video)
        }
        .refreshable {
            await fetchAllVideos()
        }
        .overlay {
            if isLoading {
                UniversalProgressView()
            }
        }
    }

    private func fetchAllVideos() async {
        isLoading = true
        defer { isLoading = false }
        
        let channels = try? modelContext.fetch(FetchDescriptor<Channel>())
        
        for channel in channels ?? [] {
            do {
                let channelVideos = try await fetchChannelVideosFromRSS(channel: channel)
                for video in channelVideos {
                    modelContext.upsertVideo(video)
                }
            } catch {
                print("Error fetching videos for \(channel.title): \(error)")
            }
        }
    }

    private func fetchChannelVideosFromRSS(channel: Channel) async throws -> [Video] {
        let url = URL(string: "https://www.youtube.com/feeds/videos.xml?channel_id=\(channel.id)")!
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        let parser = FeedParser()
        parser.parse(data: data)
        
        guard let feed = parser.feed else {
            throw APIError.invalidResponse
        }
        
        return feed.entries.prefix(10).map { entry in
            Video(
                id: entry.mediaGroup.videoId,
                title: entry.title,
                videoDescription: entry.mediaGroup.description,
                thumbnailURL: entry.mediaGroup.thumbnail.url,
                publishedAt: entry.published,
                channelTitle: entry.author.name,
                url: entry.link,
                channel: channel
            )
        }
    }
}
