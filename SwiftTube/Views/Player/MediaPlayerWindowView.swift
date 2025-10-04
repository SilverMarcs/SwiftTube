import SwiftUI

struct MediaPlayerWindowView: View {
    @Environment(VideoManager.self) var videoManager
    
    @State private var showDetail = false

    var body: some View {
        ScrollView {
            VideoPlayerView()
                .gesture(WindowDragGesture())
                .onTapGesture(count: 2, perform: toggleFullscreen)
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
                .navigationTitle(videoManager.currentVideo?.title ?? "Loading")
                .preferredColorScheme(.dark)
                .onDisappear {
                    videoManager.dismiss()
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
                        VideoDetailView(video: video)
                            .frame(height: 500)
                    }
                }
        }
        .ignoresSafeArea(edges: .top)
        .background(.black, ignoresSafeAreaEdges: .all)
    }
    
    private func toggleFullscreen() {
        if let window = NSApplication.shared.keyWindow {
            window.toggleFullScreen(nil)
        }
    }
}
