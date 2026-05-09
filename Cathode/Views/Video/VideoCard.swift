import SwiftUI
import SwiftMediaViewer

struct VideoCard: View {
    @Environment(CloudStoreManager.self) private var userDefaults
    let video: Video
    var showChannelLink: Bool = true
    
    var body: some View {
        PlayVideoButton(video: video) {
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
                    .overlay(alignment: .bottom) {
                        if let progress = video.watchProgressRatio {
                            ProgressView(value: progress)
                                .tint(.accent)
                                #if os(macOS)
                                .controlSize(.mini)
                                .padding(.bottom, -3)
                                #endif
                        }
                    }
                
                VStack(alignment: .leading) {
                    Text(video.title)
                        .font(.headline)
                        #if os(macOS)
                        .lineLimit(2, reservesSpace: true)
                        #else
                        .lineLimit(2)
                        #endif
                    
                    HStack(alignment: .center, spacing: 4) {
                        if let url = URL(string: video.channel.thumbnailURL) {
                            CachedAsyncImage(url: url, targetSize: 50)
                                .frame(width: 20, height: 20)
                                .clipShape(.circle)
                        }
                        
                        Text(video.channel.title)
                            .lineLimit(1)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.leading, 2)
                        
                        Spacer()

                        HStack(spacing: 4) {
                            Label {
                                if let viewCount = video.viewCountValue {
                                    Text(viewCount, format: .number.notation(.compactName))
                                        .font(.footnote)
                                } else {
                                    Text(video.viewCount)
                                        .font(.footnote)
                                }
                            } icon: {
                                Image(systemName: "eye")
                                    .font(.system(size: 10))
                            }
                            .labelIconToTitleSpacing(2)
                            

                            Label {
                                Text(video.publishedAt.customRelativeFormat())
                                    .font(.footnote)
                            } icon: {
                                Image(systemName: "clock")
                                    .font(.system(size: 10))
                            }
                            #if os(macOS)
                            .labelIconToTitleSpacing(1)
                            #else
                            .labelIconToTitleSpacing(0)
                            #endif
                            
                            if userDefaults.isWatchLater(video.id) {
                                Image(systemName: "bookmark.fill")
                                    .foregroundStyle(.green)
                                    .font(.system(size: 10))
                            }
                        }
                        .padding(.bottom, -1)
                    }
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .clipShape(.rect(cornerRadius: 12))
            .background(.background.secondary, in: .rect(cornerRadius: 12))
        }
        #if !os(macOS)
        .contentShape(.contextMenuPreview, .rect(cornerRadius: 12))
        #endif
        .videoContextMenu(video: video, showChannelLink: showChannelLink)
    }
}
