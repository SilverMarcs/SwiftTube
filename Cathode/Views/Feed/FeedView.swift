import SwiftMediaViewer
import SwiftUI

struct FeedView: View {
    @Environment(VideoLoader.self) private var videoLoader
    @Environment(GoogleAuthManager.self) private var authManager
    @Environment(CloudStoreManager.self) private var userDefaults

    @State private var isRandomOrderEnabled = false
    @State private var randomizedVideos: [Video] = []

    private var displayedVideos: [Video] {
        isRandomOrderEnabled ? randomizedVideos : videoLoader.videos
    }

    var body: some View {
        VideoGridView(videos: displayedVideos) {
            #if os(tvOS)
            if let recent = userDefaults.historyVideos.first {
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
            // Feed-only search moved to SearchView's "Feed" scope.
            // #if !os(tvOS)
            // .searchable(text: $searchText, placement: searchPlacement, prompt: "Search feed")
            // .searchPresentationToolbarBehavior(.avoidHidingContent)
            // #endif
            .onChange(of: videoLoader.videos) { _, newValue in
                guard isRandomOrderEnabled else { return }
                randomizedVideos = newValue.shuffled()
            }
            .refreshable {
                await videoLoader.loadAllChannelVideos()
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
