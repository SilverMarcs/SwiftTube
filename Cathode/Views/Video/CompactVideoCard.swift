import SwiftUI
import SwiftMediaViewer

struct CompactVideoCard: View {
    @Environment(LibraryStore.self) private var library
    let video: Video

    private var watchProgressRatio: Double? {
        guard let seconds = library.resumeSeconds(for: video),
              let duration = video.duration, duration > 0 else { return nil }
        return min(seconds / duration, 1.0)
    }

    var body: some View {
        PlayVideoButton(video: video) {
            HStack {
                CachedAsyncImage(url: video.thumbnailURL, targetSize: 500)
                    .aspectRatio(16/9, contentMode: .fill)
                    .frame(width: 100)
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
                    .overlay(alignment: .bottomTrailing) {
                        if let duration = video.duration {
                            Text(Int(duration).formatDuration())
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(RoundedRectangle(cornerRadius: 3).fill(.regularMaterial))
                                .environment(\.colorScheme, .dark)
                                .padding(6)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(video.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(2)

                        if let viewCount = video.viewCount {
                            Text("\(video.channelTitle) \u{00B7} \(viewCount, format: .number.notation(.compactName)) views")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        } else {
                            Text(video.channelTitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .videoContextMenu(video: video, showChannelLink: true)
    }
}
