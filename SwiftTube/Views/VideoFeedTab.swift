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
                    if let api = accountManager.currentAPI {
                        VideoRow(video: video, pipedAPI: api)
                    }
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
        guard let api = accountManager.currentAPI else { return }
        guard videos.isEmpty else { return }
        
        await MainActor.run { isLoadingFeed = true }
        let feedVideos = await api.fetchSubscribedFeed()
        await MainActor.run {
            videos = feedVideos
            isLoadingFeed = false
        }
    }
}
