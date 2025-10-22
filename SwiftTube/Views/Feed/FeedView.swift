import SwiftUI
import SwiftMediaViewer

struct FeedView: View {
    @Environment(VideoLoader.self) private var videoLoader
    var authmanager = GoogleAuthManager.shared
    
    @State var showSettings: Bool = false
    
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
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showSettings = true
                        } label: {
                            Label("Settings", systemImage: "gear")
                        }
                    }
                }
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                        .presentationDetents([.medium])
                }
        }
    }
}
