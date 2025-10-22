import SwiftMediaViewer
import SwiftUI

struct FeedView: View {
    @Environment(VideoLoader.self) private var videoLoader
    var authmanager = GoogleAuthManager.shared

    var body: some View {
        NavigationStack {
            VideoGridView(videos: videoLoader.videos)
                .navigationTitle("Feed")
                .toolbarTitleDisplayMode(.inlineLarge)
                .refreshable {
                    await videoLoader.loadAllChannelVideos()
                }
                .toolbar {
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
                .modifier(SettingsModifier())
        }
    }
}
