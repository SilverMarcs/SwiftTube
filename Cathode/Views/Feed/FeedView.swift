import SwiftMediaViewer
import SwiftUI

struct FeedView: View {
    @Environment(VideoLoader.self) private var videoLoader
    @Environment(LibraryStore.self) private var library
    #if os(tvOS)
    @Environment(VideoManager.self) private var videoManager
    #endif

    @State private var isRandomOrderEnabled = false
    @State private var randomizedVideos: [Video] = []

    private var displayedVideos: [Video] {
        isRandomOrderEnabled ? randomizedVideos : videoLoader.videos
    }

    var body: some View {
        VideoGridView(
            videos: displayedVideos,
            onReachEnd: {
                guard !isRandomOrderEnabled else { return }
                Task { await videoLoader.loadMore() }
            },
            onRefresh: {
                await videoLoader.loadAllChannelVideos()
            }
        ) {
            #if os(tvOS)
            if let current = videoManager.currentVideo ?? library.history.first {
                Section("Currently Playing") {
                    VideoCard(video: current)
                        .frame(maxWidth: 560)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            #endif
        }
            .onChange(of: videoLoader.videos) { _, newValue in
                guard isRandomOrderEnabled else { return }
                randomizedVideos = newValue.shuffled()
            }
            .platformTopBar("Feed") {
                Button {
                    withAnimation {
                        isRandomOrderEnabled.toggle()
                        if isRandomOrderEnabled {
                            randomizedVideos = videoLoader.videos.shuffled()
                        } else {
                            randomizedVideos = []
                        }
                    }
                } label: {
                    Image(systemName: "shuffle")
                        .foregroundStyle(isRandomOrderEnabled ? .accent : .primary)
                }
                .accessibilityLabel("Randomize")
            }
    }
}
