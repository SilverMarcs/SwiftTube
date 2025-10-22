import AVKit
import SwiftUI
import YouTubeKit

struct ShortVideoCard: View {
    let video: Video
    let player: AVPlayer
    @Binding var currentVideoId: String?

    @State private var showDetail = false
    @State private var isLoading = true

    private let fetchingSettings = FetchingSettings()

    var body: some View {
        VideoPlayer(player: player)
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
            .onAppear {
                currentVideoId = video.id
                Task { await loadVideo() }
            }
            .onDisappear {
                if currentVideoId == video.id {
                    cleanup()
                    currentVideoId = nil
                }
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
        guard currentVideoId == video.id else { return }

        isLoading = true

        player.pause()
        player.replaceCurrentItem(with: nil)

        do {
            guard currentVideoId == video.id else { return }

            let youtube = YouTube(videoID: video.id, methods: fetchingSettings.methods)
            let streams = try await youtube.streams

            guard currentVideoId == video.id else { return }

            guard
                let stream =
                    streams
                    .filterVideoAndAudio()
                    .filter({ $0.isNativelyPlayable })
                    //                .filter({ ($0.videoResolution ?? 0) <= 1080 })
                    .highestResolutionStream()
            else {
                isLoading = false
                return
            }

            guard currentVideoId == video.id else { return }

            let playerItem = AVPlayerItem(url: stream.url)
            player.replaceCurrentItem(with: playerItem)
            isLoading = false
            player.play()
        } catch {
            print("Failed to load short video: \(error)")
            isLoading = false
        }
    }

    private func cleanup() {
        player.pause()
        player.replaceCurrentItem(with: nil)
    }
}
