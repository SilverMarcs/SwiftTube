import SwiftUI

struct VideoFeedTab: View {
    @StateObject private var accountManager = AccountManager.shared
    @State private var videos: [Video] = []
    @State private var isLoadingFeed = false
    
    var body: some View {
        Group {
            if isLoadingFeed {
                VStack {
                    Spacer()
                    ProgressView("Loading feed...")
                    Spacer()
                }
            } else if videos.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "video.slash")
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary)
                    Text("No videos in feed")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Subscribe to channels to see their videos here")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding()
            } else {
                List(videos) { video in
                    VideoRow(video: video)
                }
                .listStyle(.plain)
            }
        }
        .task {
            await loadFeed()
        }
        .refreshable {
            await loadFeed()
        }
    }
    
    private func loadFeed() async {
        guard accountManager.currentAccount != nil else { return }
        guard videos.isEmpty else { return }
        
        isLoadingFeed = true
        let feedVideos = await PipedAPI.shared.fetchSubscribedFeed()
        videos = feedVideos
        isLoadingFeed = false
    }
}
