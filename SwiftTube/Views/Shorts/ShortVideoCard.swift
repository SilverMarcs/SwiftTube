import SwiftUI
import AVKit
import YouTubeKit

struct ShortVideoCard: View {
    let video: Video
    let player: AVPlayer
    
    @State private var showDetail = false
    @State private var isLoading = true
    
    var body: some View {
        VideoPlayer(player: player)
            .aspectRatio(9/16, contentMode: .fit)
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
                Task { await loadVideo() }
            }
            .onDisappear {
                cleanup()
            }
            .sheet(isPresented: $showDetail) {
                VideoDetailView(video: video)
                    .presentationDetents([.medium])
                    .presentationBackground(.bar)
                    .presentationDragIndicator(.visible)
            }
    }
    
    private func loadVideo() async {
        isLoading = true
        
        // Clean up old content first
        player.pause()
        player.replaceCurrentItem(with: nil)
        
        do {
            let youtube = YouTube(videoID: video.id, methods: [.local, .remote])
            let streams = try await youtube.streams
            
            guard let stream = streams
                .filterVideoAndAudio()
                .filter({ $0.isNativelyPlayable })
                .filter({ ($0.videoResolution ?? 0) <= 1080 })
                .highestResolutionStream() else {
                isLoading = false
                return
            }
            
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
