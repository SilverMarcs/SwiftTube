import SwiftUI
import SwiftMediaViewer

struct VideoCard: View {
    @Environment(CloudStoreManager.self) private var userDefaults
    let video: Video
    var showChannelLink: Bool = true
    var showsBookmarkIcon: Bool = true

    private var viewCountText: String {
        if let v = video.viewCountValue {
            return v.formatted(.number.notation(.compactName))
        }
        return video.viewCount
    }

    var body: some View {
        PlayVideoButton(video: video) {
            VStack(alignment: .leading) {
                CachedAsyncImage(url:  URL(string: video.thumbnailURL),targetSize: 500)
                    .aspectRatio(16/9, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .overlay(alignment: .bottomTrailing) {
                        if let duration = video.duration {
                            Text(duration.formatDuration())
                                .font(.caption)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(RoundedRectangle(cornerRadius: 4).fill(.regularMaterial))
                                .environment(\.colorScheme, .dark)
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
                        #if os(tvOS)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2, reservesSpace: true)
                        #elseif os(macOS)
                        .font(.headline)
                        .lineLimit(2, reservesSpace: true)
                        #else
                        .font(.headline)
                        .lineLimit(2)
                        #endif

                    HStack(alignment: .center, spacing: 4) {
                        if let url = URL(string: video.channel.thumbnailURL) {
                            CachedAsyncImage(url: url, targetSize: 50)
                                #if os(tvOS)
                                .frame(width: 32, height: 32)
                                #else
                                .frame(width: 20, height: 20)
                                #endif
                                .clipShape(.circle)
                        }

                        Text(video.channel.title)
                            .lineLimit(1)
                            #if os(tvOS)
                            .font(.caption)
                            #else
                            .font(.subheadline)
                            #endif
                            .fontWeight(.medium)
                            .padding(.leading, 2)
                        
                        Spacer()

                        HStack(spacing: 4) {
                            (
                                Text(viewCountText)
                                + Text(" • ").font(.body)
                                + Text(video.publishedAt.customRelativeFormat())
                            )
                            #if os(tvOS)
                            .font(.caption)
                            #else
                            .font(.footnote)
                            #endif

                            if showsBookmarkIcon, userDefaults.isBookmarked(video.id) {
                                Image(systemName: "bookmark.fill")
                                    .foregroundStyle(.green)
                                    #if os(tvOS)
                                    .font(.caption)
                                    #else
                                    .font(.system(size: 10))
                                    #endif
                            }
                        }
                        .padding(.bottom, -1)
                    }
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                #if os(tvOS)
                .padding(.bottom, 12)
                #else
                .padding(.bottom, 8)
                #endif
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
