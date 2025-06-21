import SwiftUI

struct VideoFeedTab: View {
    @State private var videos: [Video] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(videos) { video in
                    VideoRow(video: video)
                        .listRowInsets(.vertical, 7)
                        .listRowInsets(.horizontal, 10)
                        .listRowSeparator(.hidden)
                }
                
                if isLoading {
                    ProgressView()
//                        .id(UUID())
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .listRowSeparator(.hidden)
                }
            }
            .navigationDestinations()
            .listStyle(.plain)
            .navigationTitle("Feed")
            .toolbarTitleDisplayMode(.inlineLarge)
            .task {
                await loadFeed()
            }
            .refreshable {
                await loadFeed()
            }
        }
        .navigationLinkIndicatorVisibility(.hidden)
    }
    
    private func loadFeed() async {
        guard !isLoading && videos.isEmpty else { return }
        
        isLoading = true
        let feedVideos = await PipedAPI.shared.fetchSubscribedFeed()
        videos = feedVideos
        isLoading = false
    }
}
