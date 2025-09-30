import SwiftUI
import YouTubePlayerKit

struct ShortVideoCard: View {
    let video: Video
    let isActive: Bool
    let shortsManager: ShortsManager
    
    @State private var showDetail: Bool = false
    
    var body: some View {
        VStack {
            if let player = shortsManager.player, isActive, shortsManager.isPlaying(video) {
                YouTubePlayerView(player) { state in
                    switch state {
                    case .idle:
                        ProgressView()
                            .controlSize(.large)
                            .tint(.white)
                        
                    case .ready:
                        HStack {
                            if let channel = video.channel {
                                ChannelRowView(item: channel)
                                    .foregroundStyle(.white)
                                    .shadow(color: .black, radius: 6, x: 0, y: 2)
                                    .navigationLinkIndicatorVisibility(.hidden)
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
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                        
                    case .error(let error):
                        ContentUnavailableView(
                            "Video Unavailable",
                            systemImage: "exclamationmark.triangle.fill",
                            description: Text(error.localizedDescription)
                        )
                    }
                }
                .aspectRatio(9/16, contentMode: .fit)
                .clipped()
            }
        }
        .sheet(isPresented: $showDetail) {
            VideoDetailView(video: video)
                .presentationDetents([.medium])
                .presentationBackground(.bar)
        }
    }
}
