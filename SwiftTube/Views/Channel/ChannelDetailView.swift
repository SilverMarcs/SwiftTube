import SwiftUI
import SwiftData

struct ChannelDetailView: View {
    let channelItem: ChannelDisplayable
    @State private var videos: [Video] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            List(videos) { video in
                VideoCard(video: video)
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
            .navigationTitle(channelItem.title)
            .toolbarTitleDisplayMode(.inline)
            .task {
                if videos.isEmpty {
                    await loadChannelVideos()
                }
            }
            .refreshable {
                await loadChannelVideos()
            }
        }
    }
    
    private func loadChannelVideos() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            videos = try await FeedParser.fetchChannelVideosFromRSS(channelId: channelItem.id, maxResults: 20)
        } catch {
            print(error.localizedDescription)
        }
    }
}

#Preview {
    let subscription = Subscription(
        id: "UCBJycsmduvYEL83R_U4JriQ",
        title: "Marques Brownlee",
        description: "Technology reviews and discussions",
        thumbnailURL: "https://example.com/thumbnail.jpg",
        channelId: "UCBJycsmduvYEL83R_U4JriQ"
    )
    
    ChannelDetailView(channelItem: subscription)
}
