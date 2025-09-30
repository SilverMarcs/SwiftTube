import SwiftUI
import SwiftMediaViewer
import YouTubePlayerKit

struct MiniPlayerAccessoryView: View {
    @Environment(VideoManager.self) var manager
    @Environment(\.tabViewBottomAccessoryPlacement) var placement
    
    var body: some View {
        Group {
            if let video = manager.currentVideo {
                if placement == .inline {
                    HStack {
                        CachedAsyncImage(url: URL(string: video.thumbnailURL), targetSize: 500)
                            .aspectRatio(4/3, contentMode: .fill)
                            .frame(maxWidth: 40, maxHeight: 34)
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
                            Image(systemName: manager.playbackState == .playing ? "pause.fill" : "play.fill")
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
                            Task { await manager.togglePlayPause() }
                        } label: {
                            Image(systemName: manager.playbackState == .playing ? "pause.fill" : "play.fill")
                                .contentTransition(.symbolEffect(.replace))
                        }
                        
//                       Button {
//                           manager.dismiss()
//                       } label: {
//                           Image(systemName: "xmark")
//                               .font(.title3)
//                       }
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
}
