import SwiftUI
import SwiftMediaViewer

/// tvOS player info tab listing the current video's related / "up next" videos
/// (from `VideoManager.upNextVideos`, sourced from InnerTube's `/next`). Reuses
/// the horizontal-rail card UI from the former channel-videos tab; selecting a
/// card follows the standard `PlayVideoButton` flow.
struct PlayerRelatedTab: View {
    @Environment(VideoManager.self) private var videoManager

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 35) {
                ForEach(videoManager.upNextVideos) { video in
                    PlayerRelatedVideoCard(video: video)
                }
            }
        }
        .scrollClipDisabled()
        .overlay {
            if videoManager.upNextVideos.isEmpty {
                if videoManager.isLoadingUpNext {
                    UniversalProgressView()
                } else {
                    Text("No related videos.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct PlayerRelatedVideoCard: View {
    let video: Video

    var body: some View {
        PlayVideoButton(video: video) {
            HStack(spacing: 0) {
                CachedAsyncImage(url: video.thumbnailURL, targetSize: 400)
                    .aspectRatio(16/9, contentMode: .fill)
                    .frame(width: 360, height: 240)
                    .clipped()

                VStack(alignment: .leading, spacing: 6) {
                    Text(video.title)
                        .font(.callout.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let v = video.viewCount {
                        if let date = video.publishedAt {
                            Text("\(v.formatted(.number.notation(.compactName))) views • \(date.customRelativeFormat())")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("\(v.formatted(.number.notation(.compactName))) views")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if let date = video.publishedAt {
                        Text(date.customRelativeFormat())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(width: 760, height: 240)
        }
    }
}
