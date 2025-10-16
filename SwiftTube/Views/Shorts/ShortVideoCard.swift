import SwiftUI
import AVKit
import YouTubeKit

struct ShortVideoCard: View {
    let video: Video
    let isActive: Bool
    let player: AVPlayer // Receive player from parent
    
    @State private var showDetail: Bool = false
    @State private var isLoading: Bool = true
    
    var body: some View {
        ZStack {
            if isActive {
                VideoPlayer(player: player)
                    .aspectRatio(9/16, contentMode: .fit)
                    .clipped()
                    .overlay(alignment: .bottom) {
                        HStack {
                            ChannelRowView(channel: video.channel)
                                .foregroundStyle(.white)
                                .shadow(color: .black, radius: 20, x: 0, y: 0)
                                .navigationLinkIndicatorVisibility(.hidden)
                                .allowsHitTesting(false)
                            
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
            }
            
            if isLoading {
                UniversalProgressView()
                    .tint(.white)
            }
        }
        .task(id: isActive) {
            if isActive {
                await loadVideo()
            }
        }
        .sheet(isPresented: $showDetail) {
            VideoDetailView(video: video)
                .presentationDetents([.medium])
                .presentationBackground(.bar)
                .presentationDragIndicator(.visible)
        }
    }
    
    private func loadVideo() async {
        player.pause()
        player.replaceCurrentItem(with: nil)
        isLoading = true
        
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
            
            await MainActor.run {
                player.replaceCurrentItem(with: playerItem)
                self.isLoading = false
                player.play()
            }
        } catch {
            print("Failed to load short video: \(error)")
            isLoading = false
        }
    }
}
