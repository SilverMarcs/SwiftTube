import SwiftUI

struct PlayerChannelTab: View {
    let channel: Channel
    @State private var videos: [Video] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                UniversalProgressView()
            } else if videos.isEmpty {
                ContentUnavailableView("No videos", systemImage: "video.slash")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 30) {
                        ForEach(videos) { video in
                            VideoCard(video: video, showChannelLink: false)
                                .frame(width: 360)
                        }
                    }
                    .padding(24)
                }
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
