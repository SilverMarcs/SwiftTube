import SwiftUI
import YouTubePlayerKit

struct ShortVideoCard: View {
    @Environment(LibraryStore.self) private var library
    let video: Video
    let isActive: Bool

    @State private var showDetail = false
    @State private var iframe: YouTubePlayer?
    @State private var fetchedChannel: Channel?

    var body: some View {
        ZStack {
            Color.black
            if let iframe {
                YouTubePlayerView(iframe) { state in
                    switch state {
                    case .idle:
                        UniversalProgressView()
                    case .ready:
                        EmptyView()
                    case .error:
                        EmptyView()
                    }
                }
            }
        }
        .aspectRatio(9 / 16, contentMode: .fit)
        .clipped()
        .overlay(alignment: .bottom) {
            HStack {
                if let channelId = video.channelId, !channelId.isEmpty {
                    ChannelRowView(channel: library.channel(forId: channelId)
                                   ?? fetchedChannel
                                   ?? Channel(id: channelId, title: video.channelTitle))
                    .allowsHitTesting(false)
                    .foregroundStyle(.white)
                    .shadow(color: .black, radius: 20, x: 0, y: 0)
                    .buttonStyle(.plain)
                }

                #if !os(tvOS)
                Button {
                    showDetail = true
                } label: {
                    Image(systemName: "info")
                }
                .buttonStyle(.glass)
                #if os(macOS)
                .controlSize(.extraLarge)
                #else
                .controlSize(.large)
                #endif
                .buttonBorderShape(.circle)
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
            if isActive {
                iframe = makePlayer()
            } else {
                iframe = nil
            }
        }
        .task(id: video.channelId) {
            guard let channelId = video.channelId, !channelId.isEmpty else { return }
            if library.channel(forId: channelId) != nil { return }
            if fetchedChannel?.id == channelId { return }
            do {
                let channel = try await InnerTubeAPI.shared.fetchChannelInfo(channelId: channelId)
                if !Task.isCancelled {
                    fetchedChannel = channel
                    library.remember(channel)
                }
            } catch {
                print("ShortVideoCard channel fetch failed: \(error)")
            }
        }
        .sheet(isPresented: $showDetail) {
            VideoDetailView(video: video)
                .presentationDetents([.medium])
                #if !os(tvOS)
                .presentationBackground(.bar)
                #endif
                #if os(macOS)
                    .frame(height: 500)
                #endif
        }
    }

    private func makePlayer() -> YouTubePlayer {
        let parameters = YouTubePlayer.Parameters(
            autoPlay: true,
            loopEnabled: true,
            showControls: false,
            showFullscreenButton: false
        )
        let configuration = YouTubePlayer.Configuration(
            allowsInlineMediaPlayback: true,
            allowsPictureInPictureMediaPlayback: false
        )
        return YouTubePlayer(
            source: .video(id: video.id),
            parameters: parameters,
            configuration: configuration
        )
    }
}
