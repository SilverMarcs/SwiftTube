import SwiftUI
import SwiftMediaViewer

struct VideoCard: View {
    @Environment(VideoManager.self) var manager
    @Environment(\.modelContext) private var modelContext
    let video: Video
    
    var body: some View {
        Button {
            manager.playOrExpand(video)
        } label: {
            VStack(alignment: .leading) {
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
                    .overlay(alignment: .bottom) {
                        if let progress = video.watchProgressRatio {
                            ProgressView(value: progress)
                                .tint(.accent)
                        }
                    }
                
                VStack(alignment: .leading) {
                    Text(video.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    HStack(alignment: .center, spacing: 4) {
                        if let channel = video.channel, let url = URL(string: channel.thumbnailURL) {
                            CachedAsyncImage(url: url, targetSize: 50)
                                .frame(width: 20, height: 20)
                                .clipShape(.circle)
                        }
                        
                        Text(video.channel?.title ?? "Loading")
                            .lineLimit(1)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.leading, 2)
                        
                        Spacer()

                        HStack(spacing: 4) {
                            // Views
                            Label {
                                Text(video.viewCount.formatNumber())
                                    .font(.footnote)
                            } icon: {
                                Image(systemName: "eye")
                                    .font(.system(size: 10))
                            }
                            .labelIconToTitleSpacing(2)
                            

                            // Time
                            Label {
                                Text(video.publishedAt.customRelativeFormat())
                                    .font(.footnote)
                            } icon: {
                                Image(systemName: "clock")
                                    .font(.system(size: 10))
                            }
                            .labelIconToTitleSpacing(0)
                            
                            if video.isWatchLater {
                                Image(systemName: "bookmark.fill")
                                    .foregroundStyle(.green)
                                    .font(.system(size: 10))
                            }
                        }
                        .padding(.bottom, -1)
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
    }
}
