import SwiftUI
import AVKit

struct MediaPlayerWindowView: View {
    @Environment(NativeVideoManager.self) var videoManager
    
    @State private var showDetail = false

    var body: some View {
        ZStack(alignment: .leading) {
            Color.black
                .ignoresSafeArea()
                .contentShape(Rectangle())

            if videoManager.currentVideo != nil {
                NativeVideoPlayerView()
                    .aspectRatio(16/9, contentMode: .fit)
                    .gesture(WindowDragGesture())
                    .onTapGesture(count: 2, perform: toggleFullscreen)
                    .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
                    .navigationTitle(videoManager.currentVideo?.title ?? "Loading")
                    .preferredColorScheme(.dark)
                    .onDisappear {
                        videoManager.player?.pause()
                    }
                    .windowToolbarFullScreenVisibility(.onHover)
                    .toolbar {
                        Button {
                            showDetail = true
                        } label: {
                            Image(systemName: "info")
                        }
                    }
                    .sheet(isPresented: $showDetail) {
                        if let video = videoManager.currentVideo {
                            VideoDetailView(video: video, )
                                .frame(height: 500)
                        }
                    }
                    .ignoresSafeArea(edges: .top)
            }
        }
    }
    
    private func toggleFullscreen() {
        if let window = NSApplication.shared.keyWindow {
            window.toggleFullScreen(nil)
        }
    }
}
