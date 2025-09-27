import SwiftUI
import SwiftMediaViewer

struct MiniPlayerAccessoryView: View {
    @Environment(VideoManager.self) var manager
    @Environment(\.tabViewBottomAccessoryPlacement) var placement
    
    var body: some View {
        if let video = manager.currentVideo {
            if placement == .inline {
                HStack {
                   CachedAsyncImage(url: URL(string: video.thumbnailURL), targetSize: 500)
                       .aspectRatio(16/9, contentMode: .fill)
                        .frame(maxWidth: 60, maxHeight: 34)
                        .clipShape(.rect(cornerRadius: 10))
                    
                    Text(video.title)
                        .font(.caption)
                        .lineLimit(1)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .contentShape(.rect)
                .onTapGesture {
                    manager.isExpanded = true
                }
            } else {
                HStack {
                    CachedAsyncImage(url: URL(string: video.thumbnailURL), targetSize: 500)
                        .aspectRatio(16/9, contentMode: .fill)
                        .frame(maxWidth: 60, maxHeight: 34)
                        .clipShape(.rect(cornerRadius: 10))

                    VStack(alignment: .leading) {
                        Text(video.title)
                            .font(.headline)
                            .lineLimit(1)
                        
                        Text(video.channelTitle)
                            .font(.subheadline)
                    }
                    
                    Spacer()
                }
                .padding()
                .contentShape(.rect)
                .onTapGesture {
                    manager.isExpanded = true
                }
            }
        } else {
            EmptyView()
        }
    }
}
