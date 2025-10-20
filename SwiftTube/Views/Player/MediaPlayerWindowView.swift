import SwiftUI
import AVKit

struct MediaPlayerWindowView: View {
    @Environment(VideoManager.self) var videoManager
    
    @State private var showDetail = false

    var body: some View {
        Group {
             if videoManager.isSetting {
                UniversalProgressView()
                     .background(.black)
            } else if videoManager.currentVideo != nil {
                NativeVideoPlayerView()
                    .onDisappear {
                        videoManager.player?.pause()
                    }
            }
        }
        .ignoresSafeArea()
        .windowFullScreenBehavior(.disabled)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .aspectRatio(16/9, contentMode: .fit)
        .frame(width: 1024, height: 576)
        .gesture(WindowDragGesture())
        .navigationTitle(videoManager.currentVideo?.title ?? "Loading")
        .preferredColorScheme(.dark)
        .toolbar {
            Button {
                showDetail = true
            } label: {
                Image(systemName: "info")
            }
        }
        .sheet(isPresented: $showDetail) {
            if let video = videoManager.currentVideo {
                NavigationStack {
                    VideoDetailView(video: video, )
                        .frame(height: 500)
                }
            }
        }
    }
}
