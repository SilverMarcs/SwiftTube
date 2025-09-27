import SwiftUI
import SwiftMediaViewer

struct ActiveVideoPlayerBar: View {
    @Environment(VideoManager.self) var manager
    
    var body: some View {
        if let video = manager.currentVideo {
            HStack {
                CachedAsyncImage(url: URL(string: video.thumbnailURL), targetSize: 250)
                    .aspectRatio(16/9, contentMode: .fill)
                    .frame(width: 60, height: 34)
                    .clipShape(.rect(cornerRadius: 4))
                
                VStack(alignment: .leading) {
                    Text(video.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(video.channelTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button("Close") {
                    manager.isExpanded = false
                }
            }
            .padding()
            .background(.ultraThinMaterial)
        } else {
            EmptyView()
        }
    }
}
