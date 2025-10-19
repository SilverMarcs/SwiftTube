import SwiftUI
import SwiftMediaViewer

struct CompactVideoCard: View {
    let video: Video
    
    var body: some View {
        PlayVideoButton(video: video) {
            HStack {
                CachedAsyncImage(url: URL(string: video.thumbnailURL), targetSize: 500)
                    .aspectRatio(16/9, contentMode: .fill)
                    .frame(width: 100)
                    .overlay(alignment: .bottom) {
                        if let progress = video.watchProgressRatio {
                            ProgressView(value: progress)
                                .tint(.accent)
                                #if os(macOS)
                                .controlSize(.mini)
                                .padding(.bottom, -3)
                                #endif
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if let duration = video.duration {
                            Text(duration.formatDuration())
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .foregroundStyle(.white)
                                .background(RoundedRectangle(cornerRadius: 3).fill(.black.secondary))
                                .padding(6)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
                VStack(alignment: .leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(video.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(2)
                        
                        Text(video.channel.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .contentShape(.rect)
        }
        .videoContextMenu(video: video, showChannelLink: true)
    }
}
