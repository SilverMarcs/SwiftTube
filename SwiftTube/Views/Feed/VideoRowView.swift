import SwiftUI
import SwiftMediaViewer

struct VideoRowView: View {
    @Environment(VideoManager.self) var manager
    let video: Video
    
    var body: some View {
        Button {
            manager.currentVideo = video
            manager.isExpanded = true
        } label: {
            HStack {
                CachedAsyncImage(url:  URL(string: video.thumbnailURL),targetSize: 250)
                    .aspectRatio(16/9, contentMode: .fill)
                    .frame(width: 120, height: 68)
                    .clipShape(.rect(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text(video.channelTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Text(video.publishedAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}
