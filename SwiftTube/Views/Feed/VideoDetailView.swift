import SwiftUI
import SwiftData
import YouTubePlayerKit

struct VideoDetailView: View {
    @Environment(\.modelContext) private var modelContext
    
    let video: Video
    let namespace: Namespace.ID
    
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                // Video Title
                Text(video.title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.leading)
                
                // Video Stats (Views, Likes, Published)
                HStack {
                    Text((video.viewCount ?? "0").formatNumber())
                    Text("•")
                    Text(video.publishedAt, style: .date)
                    
                    Spacer()
                    
                    if let likesText = video.likeCount?.formatNumber() {
                        Label(likesText, systemImage: "hand.thumbsup.fill")
                    }
                }
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .padding(.top, 1)
                
                // Channel Info
                if let channel = video.channel {
                    ChannelRowView(channel: channel)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(.background.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Description
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
                
                // Comments Section
                VideoCommentsView(video: video)
                
                // Related Videos
    //            if !videoDetail.relatedVideos.isEmpty {
    //                relatedVideosSection(for: videoDetail)
    //            }
            }
            .overlay {
                if isLoading {
                   UniversalProgressView()
                }
            }
        }
        .contentMargins(10)
        .safeAreaInset(edge: .top, spacing: 0) {
            YTPlayerView(namespace: namespace)
        }
        .refreshable {
            await loadVideoDetail()
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
