import SwiftUI

struct ShortVideoCard: View {
    let video: Video
    let isActive: Bool
    
    @Environment(ShortsManager.self) var shortsManager
    
    @State private var showDetail: Bool = false
    
    var body: some View {
        VStack {
            if let player = shortsManager.player, isActive, shortsManager.isPlaying(video) {
                YTPlayerView(player: player) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            Task {
                                await shortsManager.togglePlay()
                            }
                        }
                        .overlay(alignment: .bottomLeading) {
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
                .aspectRatio(9/16, contentMode: .fit)
                .clipped()
                .sheet(isPresented: $showDetail) {
                    VideoDetailView(video: video)
                        .presentationDetents([.medium])
                        .presentationBackground(.bar)
                        .presentationDragIndicator(.visible)
                }
            }
        }
    }
}
