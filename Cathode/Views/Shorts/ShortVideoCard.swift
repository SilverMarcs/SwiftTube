import SwiftUI

struct ShortVideoCard: View {
    @Environment(LibraryStore.self) private var library
    let video: Video
    let isActive: Bool

    @State private var showDetail = false
    @State private var playback = ShortPlaybackModel()
    @State private var fetchedChannel: Channel?

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
                if let channelId = video.channelId, !channelId.isEmpty {
                    ChannelRowView(channel: library.channel(forId: channelId)
                                   ?? fetchedChannel
                                   ?? Channel(id: channelId, title: video.channelTitle))
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

}
