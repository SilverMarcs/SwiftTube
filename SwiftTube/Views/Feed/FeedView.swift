import SwiftMediaViewer
import SwiftUI

struct FeedView: View {
    @Environment(VideoLoader.self) private var videoLoader
    @Environment(GoogleAuthManager.self) private var authManager

    @State private var isRandomOrderEnabled = false
    @State private var randomizedVideos: [Video] = []

    var body: some View {
        VideoGridView(videos: isRandomOrderEnabled ? randomizedVideos : videoLoader.videos)
            .navigationTitle("Feed")
            .toolbarTitleDisplayMode(.inlineLarge)
            .onChange(of: videoLoader.videos) { _, newValue in
                guard isRandomOrderEnabled else { return }
                randomizedVideos = newValue.shuffled()
            }
            .refreshable {
                await videoLoader.loadAllChannelVideos()
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Randomize", systemImage: "shuffle") {
                        withAnimation {
                            isRandomOrderEnabled.toggle()
                            if isRandomOrderEnabled {
                                randomizedVideos = videoLoader.videos.shuffled()
                            } else {
                                randomizedVideos = []
                            }
                        }
                    }
                    .foregroundStyle(isRandomOrderEnabled ? .accent : .primary)
                }

                #if os(macOS)
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            await videoLoader.loadAllChannelVideos()
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .keyboardShortcut("r")
                }
                #endif
            }
    }
}
