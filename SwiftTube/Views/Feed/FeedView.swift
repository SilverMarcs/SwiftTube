import SwiftMediaViewer
import SwiftUI

struct FeedView: View {
    @Environment(VideoLoader.self) private var videoLoader
    @Environment(GoogleAuthManager.self) private var authManager

    var body: some View {
        VideoGridView(videos: videoLoader.videos)
            .navigationTitle("Feed")
            .toolbarTitleDisplayMode(.inlineLarge)
            .refreshable {
                await videoLoader.loadAllChannelVideos()
            }
            .modifier(SettingsModifier())
            #if os(macOS)
            .toolbar {
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
            }
            #endif
    }
}
