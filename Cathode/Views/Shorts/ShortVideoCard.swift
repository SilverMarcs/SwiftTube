import AVKit
import SwiftUI

struct ShortVideoCard: View {
    let video: Video
    let player: AVPlayer
    let isActive: Bool

    @State private var showDetail = false
    @State private var isLoading = false
    @State private var loadTask: Task<Void, Never>?

    var body: some View {
        VideoPlayer(player: isActive ? player : nil)
            .aspectRatio(9 / 16, contentMode: .fit)
            .clipped()
            .overlay(alignment: .bottom) {
                HStack {
                    #if !os(macOS)
                        ChannelRowView(channel: video.channel)
                            .foregroundStyle(.white)
                            .shadow(color: .black, radius: 20, x: 0, y: 0)
                            .navigationLinkIndicatorVisibility(.hidden)
                            .allowsHitTesting(false)
                    #endif

                    Spacer()

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
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .overlay {
                if isLoading {
                    UniversalProgressView()
                        .tint(.white)
                }
            }
            .task(id: isActive) {
                cancelLoadTask()

                if isActive {
                    loadTask = Task { await loadVideo() }
                }
                // No cleanup on deactivation: the shared player is owned by the
                // currently-active card. The next active card's loadVideo() will
                // reset and replace the item. Letting the outgoing card touch the
                // player races with the incoming card's setup (since cache hits
                // are now near-instant) and blanks playback.
            }
            .onDisappear {
                cancelLoadTask()
            }
            .sheet(isPresented: $showDetail) {
                VideoDetailView(video: video)
                    .presentationDetents([.medium])
                    .presentationBackground(.bar)
                    #if os(macOS)
                        .frame(height: 500)
                    #endif
            }
    }

    private func loadVideo(allowCacheRetry: Bool = true) async {
        guard !Task.isCancelled else { return }

        await MainActor.run {
            isLoading = true
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }

        guard let url = await StreamURLCache.shared.fetch(id: video.id) else {
            print("Failed to load short video: no playable stream")
            return
        }
        if Task.isCancelled { return }

        let playerItem = AVPlayerItem(url: url)
        await MainActor.run {
            player.replaceCurrentItem(with: playerItem)
            player.play()
        }

        let ready = await awaitPlayerItemReady(playerItem)
        if Task.isCancelled { return }
        if !ready && allowCacheRetry {
            // Likely a stale/expired stream URL — drop it and retry once with a fresh fetch.
            await StreamURLCache.shared.evict(id: video.id)
            await loadVideo(allowCacheRetry: false)
        }
    }

    private func cancelLoadTask() {
        loadTask?.cancel()
        loadTask = nil
    }
}
