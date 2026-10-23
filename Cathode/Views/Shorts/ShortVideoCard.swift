import SwiftUI

struct ShortVideoCard: View {
    @Environment(LibraryStore.self) private var library
    let video: Video
    let isActive: Bool

    @State private var showDetail = false
    @State private var playback = ShortPlaybackModel()

    /// Sequence entries carry only an ID; playback's `/player` response fills the rest.
    private var resolvedVideo: Video {
        playback.source?.details.map(video.filling(from:)) ?? video
    }

    var body: some View {
        ZStack {
            Color.black
            if let source = playback.source {
                ShortPlayerView(video: video, url: source.url, isActive: isActive) { message in
                    Task { await playback.playerFailed(message, source: source, videoID: video.id) }
                }
            } else if playback.isResolving {
                UniversalProgressView()
                    .environment(\.colorScheme, .dark)
            } else if let error = playback.error {
                VStack {
                    Text(error)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Button("Retry playback", systemImage: "arrow.clockwise") {
                        Task { await playback.retry(videoID: video.id) }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
        .aspectRatio(9 / 16, contentMode: .fit)
        .clipped()
        .overlay(alignment: .bottom) {
            HStack {
                if let channelId = resolvedVideo.channelId, !channelId.isEmpty {
                    ChannelRowView(channel: library.channel(forId: channelId)
                                   ?? Channel(id: channelId, title: resolvedVideo.channelTitle))
                    .allowsHitTesting(false)
                    .foregroundStyle(.white)
                    .shadow(color: .black, radius: 20, x: 0, y: 0)
                    .buttonStyle(.plain)
                }

                // Info button hidden for now — Shorts carry no per-item metadata to
                // show. Uncomment to restore the detail sheet.
                #if !os(tvOS)
                // Button {
                //     showDetail = true
                // } label: {
                //     Image(systemName: "info")
                // }
                // .buttonStyle(.glass)
                // #if os(macOS)
                // .controlSize(.extraLarge)
                // #else
                // .controlSize(.large)
                // #endif
                // .buttonBorderShape(.circle)
                #endif
            }
            .padding(.horizontal, 16)
            #if os(macOS)
            .padding(.bottom, 35)
            #elseif os(iOS)
            .padding(.bottom, 30)
            #else
            .padding(.bottom, 20)
            #endif
        }
        .task(id: isActive) {
            guard isActive else { return }
            await playback.resolveIfNeeded(videoID: video.id)
        }
        .task(id: resolvedVideo.channelId) {
            guard let channelId = resolvedVideo.channelId, !channelId.isEmpty else { return }
            await library.loadChannel(forId: channelId)
        }
        .sheet(isPresented: $showDetail) {
            VideoDetailView(video: resolvedVideo)
                .presentationDetents([.medium])
                #if !os(tvOS)
                .presentationBackground(.bar)
                #endif
                #if os(macOS)
                    .frame(height: 500)
                #endif
        }
    }

}
