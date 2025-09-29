import SwiftUI
import SwiftMediaViewer

struct MiniPlayerAccessoryView: View {
    @Environment(VideoManager.self) var manager
    @Environment(\.tabViewBottomAccessoryPlacement) var placement
    
    var body: some View {
        if let video = manager.currentVideo {
            if placement == .inline {
                HStack {
                   CachedAsyncImage(url: URL(string: video.thumbnailURL), targetSize: 250)
                       .aspectRatio(16/9, contentMode: .fill)
                        .frame(maxWidth: 60, maxHeight: 34)
                        .clipShape(.rect(cornerRadius: 10))
                    
                    Text(video.title)
                        .font(.subheadline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Button {
                        Task {
                            await manager.togglePlayPause()
                        }
                    } label: {
                        Image(systemName: manager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal)
                .contentShape(.rect)
                .onTapGesture {
                    manager.isExpanded = true
                }
            } else {
                HStack {
                    CachedAsyncImage(url: URL(string: video.thumbnailURL), targetSize: 250)
                        .aspectRatio(16/9, contentMode: .fill)
                        .frame(maxWidth: 60, maxHeight: 34)
                        .clipShape(.rect(cornerRadius: 10))

                    VStack(alignment: .leading) {
                        Text(video.title)
                            .font(.subheadline)
                            .lineLimit(1)
                        
                        Text(video.channel?.title ?? "Title")
                            .font(.caption)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        Task {
                            await manager.togglePlayPause()
                        }
                    }) {
                        Image(systemName: manager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.subheadline)
                    }
                }
                .padding()
                .contentShape(.rect)
                .onTapGesture {
                    manager.isExpanded = true
                }
            }
        } else {
//            Text("No video playing")
            EmptyView()
        }
    }
}
