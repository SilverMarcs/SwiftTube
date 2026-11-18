#if os(iOS)
import SwiftUI
import SwiftMediaViewer

struct ShortsPageOverlay: View {
    @Environment(LibraryStore.self) private var library

    let video: Video
    let feed: ShortsFeed
    let showsChannel: Bool

    var body: some View {
        let playback = feed.playback(for: video.id)
        let resolvedVideo = playback?.source?.details.map(video.filling(from:)) ?? video

        ZStack(alignment: .bottomLeading) {
            if let error = playback?.error {
                VStack {
                    Text(error)
                        .multilineTextAlignment(.center)
                    Button("Retry playback", systemImage: "arrow.clockwise") {
                        Task { await playback?.retry(videoID: video.id) }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if playback?.source == nil {
                UniversalProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
            }
            if showsChannel {
                let channel = library.channel(for: resolvedVideo)
                let name = channel?.title ?? resolvedVideo.channelTitle
                if !name.isEmpty {
                    HStack {
                        CachedAsyncImage(
                            url: resolvedVideo.channelAvatarURL ?? channel?.thumbnailURL,
                            targetSize: 100
                        ) {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(.circle)
                        .accessibilityHidden(true)
                        Text(name)
                            .font(.headline)
                            .lineLimit(1)
                    }
                    .padding(4)
                    .padding(.trailing)
                    .glassEffect()
                    .padding(.bottom)
                    .allowsHitTesting(false)
                }
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .task(id: video.id) {
            await feed.activate(video)
        }
        .task(id: resolvedVideo.channelId) {
            guard let id = resolvedVideo.channelId, !id.isEmpty,
                  resolvedVideo.channelAvatarURL == nil else { return }
            await library.loadChannel(forId: id)
        }
    }
}
#endif
