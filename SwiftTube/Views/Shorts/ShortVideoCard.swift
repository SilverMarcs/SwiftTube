import SwiftUI

struct ShortVideoCard: View {
    let video: Video
    let isActive: Bool
    
    @Environment(ShortsManager.self) var shortsManager
    
    @State private var showDetail: Bool = false
    @State private var isPlaying: Bool = true // Assume starts playing
    
    var body: some View {
        VStack {
            if let player = shortsManager.player, isActive, shortsManager.isPlaying(video) {
                YTPlayerView(player: player)
                    .overlay {
                        switch player.state {
                        case .idle:
                            ProgressView().controlSize(.large)
                        case .ready:
                            ZStack {
                                Color.clear
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        Task {
                                            if isPlaying {
                                                try? await player.pause()
                                            } else {
                                                try? await player.play()
                                            }
                                            isPlaying.toggle()
                                        }
                                    }
                                
                                VStack {
                                    Spacer()
                                    HStack {
                                        if let channel = video.channel {
                                            ChannelRowView(item: channel, subtitle: video.title)
                                                .foregroundStyle(.white)
                                                .shadow(color: .black, radius: 20, x: 0, y: 0)
                                                .navigationLinkIndicatorVisibility(.hidden)
                                                .allowsHitTesting(false)
                                        }
                                        
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
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        case .error(_):
                            ContentUnavailableView {
                                Label("Error", systemImage: "exclamationmark.triangle.fill")
                            } description: {
                                Text("YouTube player couldn't be loaded")
                            } actions: {
                                Button("Retry") {
                                    shortsManager.retryCurrentVideo()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                    .aspectRatio(9/16, contentMode: .fit)
                    .clipped()
                    .sheet(isPresented: $showDetail) {
                        VideoDetailView(video: video)
                            .presentationDetents([.medium])
                            .presentationBackground(.bar)
                    }
            }
        }
    }
}
