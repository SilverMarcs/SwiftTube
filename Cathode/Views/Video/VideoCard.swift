import SwiftUI
import SwiftMediaViewer

struct VideoCard: View {
    @Environment(LibraryStore.self) private var library
    let video: Video
    var showChannelLink: Bool = true
    var showsBookmarkIcon: Bool = true

    private var viewCountText: String {
        guard let v = video.viewCount else { return "" }
        return v.formatted(.number.notation(.compactName))
    }

    private var watchProgressRatio: Double? {
        guard let seconds = library.resumeSeconds(for: video),
              let duration = video.duration, duration > 0 else { return nil }
        return min(seconds / duration, 1.0)
    }

    var body: some View {
        PlayVideoButton(video: video) {
            VStack(alignment: .leading) {
                CachedAsyncImage(url: video.thumbnailURL, targetSize: 500)
                    .aspectRatio(16/9, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .overlay(alignment: .bottomTrailing) {
                        if let duration = video.duration {
                            Text(Int(duration).formatDuration())
                                .font(.caption)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(RoundedRectangle(cornerRadius: 4).fill(.regularMaterial))
                                .environment(\.colorScheme, .dark)
                                .padding(8)
                        }
                    }
                    .overlay(alignment: .bottom) {
                        if let progress = watchProgressRatio {
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
                        Text(video.channelTitle)
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
                            Group {
                                if let date = video.publishedAt {
                                    Text(viewCountText)
                                    + Text(" • ").font(.body)
                                    + Text(date.customRelativeFormat())
                                } else {
                                    Text(viewCountText)
                                }
                            }
                            #if os(tvOS)
                            .font(.caption)
                            #else
                            .font(.footnote)
                            #endif

                            if showsBookmarkIcon, library.isBookmarked(video.id) {
                                Image(systemName: "bookmark.fill")
                                    .foregroundStyle(.green)
                                    #if os(tvOS)
                                    .font(.caption)
                                    #else
                                    .font(.footnote)
                                    #endif
                                    .padding(.bottom, -2)
                            }
                        }
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
