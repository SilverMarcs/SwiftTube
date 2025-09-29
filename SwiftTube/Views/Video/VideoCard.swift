import SwiftUI
import SwiftMediaViewer

struct VideoCard: View {
    @Environment(VideoManager.self) var manager
    @Environment(\.modelContext) private var modelContext
    let video: Video
    
    var body: some View {
        Button {
            manager.currentVideo = video
            manager.isExpanded = true
        } label: {
            VStack(alignment: .leading) {
                VStack(spacing: 0) {
                    CachedAsyncImage(url:  URL(string: video.thumbnailURL),targetSize: 500)
                        .aspectRatio(16/9, contentMode: .fill)
                        .overlay(alignment: .bottomTrailing) {
                            if let duration = video.duration {
                                Text(duration.formatDuration())
                                    .font(.caption)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .foregroundStyle(.white)
                                    .background(RoundedRectangle(cornerRadius: 4).fill(.black.secondary))
                                    .padding(8)
                            }
                        }
                    
                    
                    if let progress = watchProgressRatio {
                        ProgressView(value: progress)
                            .tint(.accent)
                    }
                }
                
                VStack(alignment: .leading) {
                    Text(video.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    HStack(alignment: .center, spacing: 5) {
                        if let channel = video.channel, let url = URL(string: channel.thumbnailURL) {
                            CachedAsyncImage(url: url, targetSize: 50)
                                .frame(width: 20, height: 20)
                                .clipShape(.circle)
                        }
                        
                        Text(video.channel?.title ?? "Loading")
                            .lineLimit(1)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Spacer()
                        
                        Group {
                            Text(video.viewCount.formatNumber() + " views")
                            
                            Text("•")
                                .fontWeight(.light)
                            
                            Text(video.publishedAt.customRelativeFormat())
                        }
                        .padding(.bottom, -1)
                        .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .background(.background.secondary, in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                video.isWatchLater.toggle()
            } label: {
                Label(
                    video.isWatchLater ? "Remove from Watch Later" : "Add to Watch Later",
                    systemImage: video.isWatchLater ? "bookmark.fill" : "bookmark"
                )
            }
        }
    }
}

private extension VideoCard {
    var watchProgressRatio: Double? {
        guard let duration = video.duration, duration > 0 else { return nil }
        let ratio = video.watchProgressSeconds / Double(duration)
        let clamped = min(max(ratio, 0), 1)
        return clamped > 0 ? clamped : nil
    }
}
