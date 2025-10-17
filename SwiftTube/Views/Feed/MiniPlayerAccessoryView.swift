import SwiftUI
import SwiftMediaViewer

struct MiniPlayerAccessoryView: View {
    @Environment(VideoManager.self) var manager
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
                    #if os(macOS)
                    .keyboardShortcut(.space, modifiers: [])
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.circle)
                    .controlSize(.large)
                    #else
                    .tint(.primary)
                    #endif
    
                }
                .contentShape(.rect)
                .onTapGesture {
                    #if os(macOS)
                    openWindow(id: "media-player")
                    #else
                    manager.isExpanded = true
                    #endif
                }
                .padding(.vertical, 8)
                #if !os(macOS)
                .padding(.horizontal, 18)
                .glassEffect(.clear)
                .padding(.horizontal, 20)
                .padding(.vertical, 7)
                #else
                .padding(.horizontal, 10)
                #endif
            }
        }
    }
}
