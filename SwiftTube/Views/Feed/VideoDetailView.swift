import SwiftUI
import SwiftData
import YouTubePlayerKit

struct VideoDetailView: View {
    @Environment(VideoManager.self) var manager
    @Environment(\.modelContext) private var modelContext
    
    let video: Video
    let namespace: Namespace.ID
    
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    // Title
                    Text(video.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    // Channel & Date
                    HStack {
                        Text(video.channelTitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Text(video.publishedAt, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Stats Row
                    HStack {
                        Label((video.viewCount ?? "0").formatNumber() + " views", systemImage: "eye")
                        
                        if let likes = video.likeCount {
                            Label(likes.formatNumber(), systemImage: "hand.thumbsup")
                        }
                        
                        if let comments = video.commentCount {
                            Label(comments.formatNumber(), systemImage: "bubble.left")
                        }
                        
                        Spacer()
                        
//                        Text(formatDurationFromSeconds(video.duration))
//                            .font(.caption.monospaced())
//                            .padding(.horizontal, 8)
//                            .padding(.vertical, 2)
//                            .background(.background.secondary)
//                            .clipShape(.capsule)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    
                    // Technical Info
                    
                    Divider()
                    
                    // Description
                    Text("Description")
                        .font(.headline)
                    
                    Text(LocalizedStringKey(video.videoDescription))
                        .font(.body)
                }
            }
            .padding(10)
            .overlay {
                if isLoading {
                   UniversalProgressView()
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            YTPlayerView()
        }
        // .task {
        //     await loadVideoDetail()
        // }
    }
    
    private func loadVideoDetail() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await fetchVideoDetail(for: video)
            try? modelContext.save()
        } catch {
            print(error.localizedDescription)
        }
    }
    
    private func fetchVideoDetail(for video: Video) async throws {
        try await YTService.fetchVideoDetails(for: video)
    }
}
