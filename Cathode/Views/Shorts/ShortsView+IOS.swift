#if os(iOS)
import AVFoundation
import SwiftUI
import SwiftMediaViewer

struct ShortsView: View {
    @Environment(VideoLoader.self) private var videoLoader
    @Environment(VideoManager.self) private var videoManager

    @State private var feed: ShortsFeed?
    @State private var hasLoaded = false

    var body: some View {
        Group {
            if let feed, let first = videoLoader.shortVideos.first {
                SMVEmbeddedVideoFeed(
                    firstItem: ShortsFeed.item(for: first),
                    feed: feed,
                    scrubber: .withControls,
                    playbackURL: { feed.playback(for: $0.id)?.source?.url },
                    onPlayerChange: feed.playerChanged
                ) { page in
                    if page.isCurrent,
                       let video = videoLoader.shortVideos.first(where: { $0.id == page.item.id }) {
                        ShortsPageOverlay(video: video, feed: feed, showsChannel: page.isShowingControls)
                    }
                }
            } else if hasLoaded {
                ContentUnavailableView("No Shorts", systemImage: "play.rectangle.on.rectangle")
            } else {
                UniversalProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
        .environment(\.colorScheme, .dark)
        .task {
            videoManager.player?.pause()
            guard feed == nil else { return }
            if videoLoader.shortVideos.isEmpty {
                await videoLoader.loadShorts()
                while videoLoader.shortVideos.isEmpty, videoLoader.hasMoreShorts, !Task.isCancelled {
                    do {
                        try await videoLoader.fetchMoreShorts()
                    } catch {
                        break
                    }
                }
            }
            guard !Task.isCancelled else { return }
            if !videoLoader.shortVideos.isEmpty {
                feed = ShortsFeed(loader: videoLoader)
            }
            hasLoaded = true
        }
    }
}
#endif
