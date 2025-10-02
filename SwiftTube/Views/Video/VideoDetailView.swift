import SwiftUI
import SwiftData
import SwiftMediaViewer

struct VideoDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(VideoManager.self) var manager
    
    let video: Video    
    
    @State private var isLoading = false
    @State var showDetail: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading) {
                    // Video Title
                    Text(video.title)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.leading)
                    
                    // Video Stats (Views, Likes, Published)
                    HStack(spacing: 5) {
                        Label(video.viewCount.formatNumber(), systemImage: "eye")
                            .labelIconToTitleSpacing(2)
                        
                        Text("•")
                        Text(video.publishedAt, style: .date)
                        
                        Spacer()
                        
                        if let likesText = video.likeCount?.formatNumber() {
                            Label(likesText, systemImage: "hand.thumbsup.fill")
                        }
                        
                        Button {
                            video.isWatchLater.toggle()
                            try? modelContext.save()
                        } label: {
                            Label(
                                video.isWatchLater ? "Remove from Watch Later" : "Add to Watch Later",
                                systemImage: video.isWatchLater ? "bookmark.fill" : "bookmark"
                            )
                            .labelStyle(.iconOnly)
                        }
                        .foregroundStyle(video.isWatchLater ? .green : .secondary)
                        .buttonStyle(.glass)
                        .controlSize(.mini)
                    }
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .padding(.top, 1)
                    
                    // Channel Info
                    if let channel = video.channel {
                        ChannelRowView(item: channel)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(.background.secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.primary)
                    }
                    
                    // Description
                    if !video.videoDescription.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.headline)
                            
                            ExpandableText(text: video.videoDescription, maxCharacters: 200)
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading) // Add this line
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(.background.secondary))
                    }
                    
                    // Comments Section
                    VideoCommentsView(video: video)
                }
                .padding(10)
                .overlay {
                    if isLoading {
                        UniversalProgressView()
                    }
                }
            }
        }
    }

    private func loadVideoDetail() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await YTService.fetchVideoDetails(for: video)
            try? modelContext.save()
        } catch {
            print(error.localizedDescription)
        }
    }
}
