import SwiftUI
import AVKit

struct AVPlayerViewMac: View {
    @Environment(VideoManager.self) var videoManager
    
    @State private var showDetail = false
    
    var body: some View {
        Group {
            if videoManager.isSetting {
                UniversalProgressView()
                    .background(.black)
            } else if let player = videoManager.player {
                AVPlayerMac(player: player)
                    .onDisappear {
                        videoManager.player?.pause()
                    }
            }
        }
        .ignoresSafeArea()
        .windowFullScreenBehavior(.disabled)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .gesture(WindowDragGesture())
        .navigationTitle(videoManager.currentVideo?.title ?? "Loading")
        .navigationSubtitle(videoManager.currentVideo?.channel.title ?? "Channel")
        .preferredColorScheme(.dark)
        .toolbar {
            Button {
                showDetail.toggle()
            } label: {
                Image(systemName: "info")
            }
        }
        .inspector(isPresented: $showDetail) {
            if let video = videoManager.currentVideo {
                VideoDetailView(video: video)
                    .id(video.id)
            }
        }
        .onAppear {
            if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "media-player" }) {
                window.aspectRatio = NSSize(width: 16, height: 9)
                window.setContentSize(NSSize(width: 1024, height: 576))
            }
        }
    }
}
