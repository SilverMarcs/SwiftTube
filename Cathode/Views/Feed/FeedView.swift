import SwiftMediaViewer
import SwiftUI

struct FeedView: View {
    @Environment(VideoLoader.self) private var videoLoader
    @Environment(GoogleAuthManager.self) private var authManager

    @State private var isRandomOrderEnabled = false
    @State private var randomizedVideos: [Video] = []
    @State private var searchText = ""

    private var displayedVideos: [Video] {
        let base = isRandomOrderEnabled ? randomizedVideos : videoLoader.videos
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return base }
        return base.filter { video in
            video.title.localizedCaseInsensitiveContains(query)
                || video.channel.title.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VideoGridView(videos: displayedVideos)
            #if os(macOS)
            .contentMargins(.top, 10)
            #endif
            .navigationTitle("Feed")
            .toolbarTitleDisplayMode(.inlineLarge)
            .searchable(text: $searchText, placement: searchPlacement, prompt: "Search feed")
            .searchPresentationToolbarBehavior(.avoidHidingContent)
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

    private var searchPlacement: SearchFieldPlacement {
        #if os(macOS)
        .toolbarPrincipal
        #else
        .automatic
        #endif
    }
}
