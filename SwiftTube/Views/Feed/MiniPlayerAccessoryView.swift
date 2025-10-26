import SwiftUI
import SwiftMediaViewer
import AVKit

struct MiniPlayerAccessoryView: View {
    @Environment(VideoManager.self) var manager
    @Environment(\.openWindow) private var openWindow
    @Environment(\.tabViewBottomAccessoryPlacement) var placement
    
    var body: some View {
        if let video = manager.currentVideo {
            HStack {
                Group {
#if os(macOS)
                    CachedAsyncImage(url: URL(string: video.thumbnailURL), targetSize: 500)
#else
                    AsyncImage(url: URL(string: video.thumbnailURL))
#endif
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 34)
                .clipShape(.rect(cornerRadius: 10))
                
                VStack(alignment: .leading) {
                    Text(video.title)
                        .font(.system(size: 13))
                        .bold()
                        .lineLimit(1)
                    
                    Text(video.channel.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Button {
                    manager.togglePlayPause()
                } label: {
                    Image(systemName: manager.player?.timeControlStatus == .playing ? "pause.fill" : "play.fill")
                        .contentTransition(.symbolEffect(.replace))
                }
                #if os(macOS)
                .keyboardShortcut(.space, modifiers: [])
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                #endif

            }
            .contentShape(.rect)
            .padding(.horizontal, 12)
            #if os(macOS)
            .padding(.vertical, 8)
            #else
            .onTapGesture {
                manager.isExpanded = true
            }
            #endif
        }
    }
}
