import SwiftUI

struct PlayerChannelTab: View {
    let channel: Channel
    @State private var videos: [Video] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 30) {
                ForEach(videos) { video in
                    VideoCard(video: video, showChannelLink: false)
                        // .frame(width: 360)
                }
            }
            .padding(24)
        }
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
        .task {
            do {
                videos = try await FeedParser.fetchChannelVideosFromRSS(channel: channel)
            } catch {
                videos = []
            }
            isLoading = false
        }
    }
}
