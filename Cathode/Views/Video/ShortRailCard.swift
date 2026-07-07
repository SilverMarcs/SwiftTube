import SwiftUI
import SwiftMediaViewer

/// Compact portrait (9:16) card for a horizontal Shorts rail, e.g. atop History.
/// Tapping plays the Short in the standard player via `PlayVideoButton`.
struct ShortRailCard: View {
    let video: Video

    #if os(tvOS)
    private let width: CGFloat = 200
    #else
    private let width: CGFloat = 120
    #endif

    var body: some View {
        PlayVideoButton(video: video) {
            VStack(alignment: .leading, spacing: 6) {
                Color.clear
                    .aspectRatio(9 / 16, contentMode: .fit)
                    .overlay {
                        CachedAsyncImage(url: video.thumbnailURL, targetSize: 400)
                            .scaledToFill()
                    }
                    .clipped()
                    .clipShape(.rect(cornerRadius: 12))

                Text(video.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 2)
            }
            .frame(width: width)
        }
        #if !os(macOS)
        .contentShape(.contextMenuPreview, .rect(cornerRadius: 12))
        #endif
        .videoContextMenu(video: video, showChannelLink: true)
    }
}
