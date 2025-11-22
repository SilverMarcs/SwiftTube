import AVKit
import SwiftUI
@preconcurrency import YouTubeKit

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
                    .controlSize(.large)
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
                } else {
                    cleanup()
                }
            }
            .onDisappear {
                cancelLoadTask()
                cleanup()
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

    private func loadVideo() async {
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

        do {
            // Fetch stream URL on demand using YouTubeKit
            let methods = FetchingSettings().methods
            let youtube = YouTube(videoID: video.id, methods: methods)
            let streams = try await youtube.streams
            try Task.checkCancellation()

            guard let stream = streams
                .filterVideoAndAudio()
                .filter({ $0.isNativelyPlayable })
                .highestResolutionStream()
            else {
                throw NSError(domain: "ShortVideoCard", code: 1, userInfo: [NSLocalizedDescriptionKey: "No playable stream found"])
            }

            try Task.checkCancellation()

            let playerItem = AVPlayerItem(url: stream.url)
            try Task.checkCancellation()

            await MainActor.run {
                player.replaceCurrentItem(with: playerItem)
                player.play()
            }
        } catch is CancellationError {
            await MainActor.run {
                player.pause()
                player.replaceCurrentItem(with: nil)
            }
        } catch {
            print("Failed to load short video: \(error)")
        }
    }

    private func cancelLoadTask() {
        loadTask?.cancel()
        loadTask = nil
    }

    private func cleanup() {
        Task { @MainActor in
            player.pause()
            player.replaceCurrentItem(with: nil)
            isLoading = false
        }
    }
}
