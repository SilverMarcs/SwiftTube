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
            VStack(alignment: .leading) {
                CachedAsyncImage(url:  URL(string: video.thumbnailURL),targetSize: 500)
                    .aspectRatio(16/9, contentMode: .fill)
                    .overlay(alignment: .bottomTrailing) {
                        if let duration = video.duration {
                            Text(duration.formatDuration())
                                .font(.caption)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .foregroundStyle(.white)
                                .background(RoundedRectangle(cornerRadius: 4).fill(.black.secondary))
                                .padding(8)
                        }
                     }
//                    .overlay(alignment: .bottom) {
//                       watchProgressBar
//                   }
                
                VStack(alignment: .leading) {
                    Text(video.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    HStack(alignment: .center, spacing: 5) {
                        if let channel = video.channel, let url = URL(string: channel.thumbnailURL) {
                            CachedAsyncImage(url: url, targetSize: 50)
                                .frame(width: 20, height: 20)
                                .clipShape(.circle)
                        }
                        
                        Text(video.channelTitle)
                            .lineLimit(1)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Spacer()
                        
                        Group {
                            if let count = video.viewCount {
                                Text(count.formatNumber() + " views")
                            }
                            
                            Text("•")
                                .fontWeight(.light)
                            
                            Text(video.publishedAt.customRelativeFormat())
                        }
                        .padding(.bottom, -1)
                        .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .background(.background.secondary, in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
