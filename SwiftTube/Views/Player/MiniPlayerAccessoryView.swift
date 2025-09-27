import SwiftUI
import SwiftMediaViewer

struct MiniPlayerAccessoryView: View {
    @Environment(VideoManager.self) var manager
    @Environment(\.tabViewBottomAccessoryPlacement) var placement
    
    var body: some View {
        if let video = manager.currentVideo {
            if placement == .inline {
                HStack {
//                    CachedAsyncImage(url: URL(string: video.thumbnailURL), targetSize: 250)
//                        .aspectRatio(16/9, contentMode: .fill)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(.blue.gradient)
                        .frame(maxWidth: 40, maxHeight: 40)
                        .clipShape(.rect(cornerRadius: 4))
                    
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
//                    CachedAsyncImage(url: URL(string: video.thumbnailURL), targetSize: 250)
////                        .aspectRatio(16/9, contentMode: .fill)
//                        .frame(maxWidth: 15, maxHeight: 15)
//                        .clipShape(.rect(cornerRadius: 4))
                    RoundedRectangle(cornerRadius: 5)
                        .fill(.blue.gradient)
                        .frame(maxWidth: 80, maxHeight: 80)
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
