import SwiftMediaViewer
import SwiftUI

struct FeedView: View {
    @Environment(VideoLoader.self) private var videoLoader
    @Environment(LibraryStore.self) private var library

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
            if let recent = library.history.first {
                Section("Continue Watching") {
                    VideoCard(video: recent)
                        .frame(maxWidth: 560)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            #endif
        }
            .platformNavigationToolbar()
            .navigationTitle("Feed")
            .onChange(of: videoLoader.videos) { _, newValue in
                guard isRandomOrderEnabled else { return }
                randomizedVideos = newValue.shuffled()
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
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
}
