import SwiftUI
import SwiftMediaViewer

struct MiniPlayerAccessoryView: View {
    @Environment(NativeVideoManager.self) var manager
    @Environment(\.openWindow) private var openWindow
    @Environment(\.tabViewBottomAccessoryPlacement) var placement
    
    var body: some View {
        if manager.isMiniPlayerVisible {
            if let video = manager.currentVideo {
                HStack {
                    CachedAsyncImage(url: URL(string: video.thumbnailURL), targetSize: 500)
                        .aspectRatio(4/3, contentMode: .fill)
                        .frame(maxWidth: 40, maxHeight: 34)
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
                        Image(systemName: manager.isPlaying ? "pause.fill" : "play.fill")
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .tint(.primary)
                    #if os(macOS)
                    .buttonStyle(.glassProminent)
                    .controlSize(.extraLarge)
                    .buttonBorderShape(.circle)
                    #endif
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 18)
                .contentShape(.rect)
                .onTapGesture {
                    #if os(macOS)
                    if !manager.isMediaPlayerWindowOpen {
                        openWindow(id: "media-player")
                    }
                    #else
                    manager.isExpanded = true
                    #endif
                }
//                .glassEffect(.clear)
//                .padding(.horizontal, 23)
//                .padding(.vertical, 7)
            } else {
                #if !os(macOS)
                Text("No video playing")
                #endif
            }
        }
    }
}
