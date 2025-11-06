import AVKit
import SwiftUI
@preconcurrency import YouTubeKit

struct ShortVideoCard: View {
    let video: Video
    let player: AVPlayer
    let isActive: Bool

    @State private var showDetail = false
    @State private var isLoading = false
    @State private var loopObserver: NSObjectProtocol?

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
            .onAppear {
                if isActive {
                    Task { await loadVideo() }
                }
            }
            .onDisappear {
                cleanup()
            }
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    Task { await loadVideo() }
                } else {
                    cleanup()
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
        guard isActive else { return }

        isLoading = true

        player.pause()
        player.replaceCurrentItem(with: nil)
        removeLoopObserver()

        do {
            guard isActive else { return }

            // Fetch stream URL on demand using YouTubeKit
            let methods = FetchingSettings().methods
            let youtube = YouTube(videoID: video.id, methods: methods)
            let streams = try await youtube.streams
            guard let stream = streams
                .filterVideoAndAudio()
                .filter({ $0.isNativelyPlayable })
                .highestResolutionStream()
            else {
                throw NSError(domain: "ShortVideoCard", code: 1, userInfo: [NSLocalizedDescriptionKey: "No playable stream found"])
            }

            guard isActive else { return }

            let playerItem = AVPlayerItem(url: stream.url)
            player.replaceCurrentItem(with: playerItem)
            
            // Setup looping
            setupLoopObserver(for: playerItem)
            
            isLoading = false
            player.play()
        } catch {
            print("Failed to load short video: \(error)")
            isLoading = false
        }
    }

    private func setupLoopObserver(for playerItem: AVPlayerItem) {
        // Remove any existing observer first
        removeLoopObserver()
        
        // Add observer for when video finishes playing
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak player] _ in
            guard let player, player.currentItem === playerItem else { return }
            // Seek to beginning and play again
            player.seek(to: .zero)
            player.play()
        }
    }
    
    private func removeLoopObserver() {
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
            loopObserver = nil
        }
    }

    private func cleanup() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        removeLoopObserver()
        isLoading = false
    }
}
