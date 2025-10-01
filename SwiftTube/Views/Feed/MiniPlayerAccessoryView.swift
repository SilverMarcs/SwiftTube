import SwiftUI
import SwiftMediaViewer

struct MiniPlayerAccessoryView: View {
    @Environment(VideoManager.self) var manager
    @Environment(\.tabViewBottomAccessoryPlacement) var placement
    
    var body: some View {
        if let video = manager.currentVideo, manager.isMiniPlayerVisible {
            HStack {
                CachedAsyncImage(url: URL(string: video.thumbnailURL), targetSize: 500)
                    .aspectRatio(4/3, contentMode: .fill)
                    .frame(maxWidth: 40, maxHeight: 34)
                    .clipShape(.rect(cornerRadius: 10))
                
                VStack(alignment: .leading) {
                    Text(video.title)
                        .font(.subheadline)
                        .lineLimit(1)
                    
                    Text(video.channel?.title ?? "Title")
                        .font(.caption)
                }
                
                Spacer()
                
                Button {
                    Task {
                        await manager.togglePlayPause()
                    }
                } label: {
                    Image(systemName: manager.isPlaying ? "pause.fill" : "play.fill")
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .padding()
            .contentShape(.rect)
            .onTapGesture {
                manager.isExpanded = true
            }
        } else if !manager.isMiniPlayerVisible {
            EmptyView()
        } else {
            Text("No video playing")
        }
    }
}
