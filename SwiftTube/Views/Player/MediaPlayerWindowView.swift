import SwiftUI

struct MediaPlayerWindowView: View {
    @Environment(VideoManager.self) var videoManager
    
    @State private var showDetail = false
    
    var body: some View {
        VideoPlayerView()
            .background(.black, ignoresSafeAreaEdges: .all)
            .gesture(WindowDragGesture())
            .onTapGesture(count: 2, perform: toggleFullscreen)
            .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
            .navigationTitle(videoManager.currentVideo?.title ?? "Loading")
            .ignoresSafeArea(edges: .top)
            .preferredColorScheme(.dark)
            .onDisappear {
                videoManager.dismiss()
            }
//            .overlay(alignment: .topTrailing) {
//                Button {
//                    showDetail = true
//                } label: {
//                    Image(systemName: "info")
//                }
//                .buttonStyle(.glass)
//                .controlSize(.extraLarge)
//                .buttonBorderShape(.circle)
//                .ignoresSafeArea()
//                .padding()
//            }
            .sheet(isPresented: $showDetail) {
                if let video = videoManager.currentVideo {
                    VideoDetailView(video: video)
                }
            }
    }
    
    private func toggleFullscreen() {
        if let window = NSApplication.shared.keyWindow {
            window.toggleFullScreen(nil)
        }
    }
}
