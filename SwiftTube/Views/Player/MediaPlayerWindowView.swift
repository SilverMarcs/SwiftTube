import SwiftUI

struct MediaPlayerWindowView: View {
    @Environment(VideoManager.self) var videoManager
    
    @State private var showDetail = false
    @State private var isHovering = false
    
    var body: some View {
        ScrollView {
            VStack {
                VideoPlayerView()
                    .gesture(WindowDragGesture())
                    .onTapGesture(count: 2, perform: toggleFullscreen)
                    .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
                    .navigationTitle(videoManager.currentVideo?.title ?? "Loading")
                    .ignoresSafeArea(edges: .top)
                    .preferredColorScheme(.dark)
                    .onDisappear {
                        videoManager.dismiss()
                    }
                    .onHover { hovering in
                        isHovering = hovering
                    }
                    .overlay(alignment: .topTrailing) {
                        if isHovering {
                            Button {
                                showDetail = true
                            } label: {
                                Image(systemName: "info")
                            }
                            .buttonStyle(.glass)
                            .controlSize(.extraLarge)
                            .buttonBorderShape(.circle)
                            .ignoresSafeArea()
                            .padding()
                            .transition(.opacity)
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: isHovering)
                    .sheet(isPresented: $showDetail) {
                        if let video = videoManager.currentVideo {
                            VideoDetailView(video: video)
                                .frame(height: 500)
                        }
                    }
            }
        }
        .background(.black, ignoresSafeAreaEdges: .all)
    }
    
    private func toggleFullscreen() {
        if let window = NSApplication.shared.keyWindow {
            window.toggleFullScreen(nil)
        }
    }
}
