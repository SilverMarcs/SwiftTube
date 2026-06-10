import SwiftUI

struct SharedEnvironment: ViewModifier {
    let videoLoader: VideoLoader
    let videoManager: VideoManager
    let store: LibraryStore
    let ytAuth: YTTVAuthManager
    let cookieAuth: YTCookieAuth

    func body(content: Content) -> some View {
        content
            .environment(videoLoader)
            .environment(videoManager)
            .environment(store)
            .environment(ytAuth)
            .environment(cookieAuth)
            .accentColor(.accent)
            .environment(\.openURL, OpenURLAction { url in
                if let videoId = url.youtubeVideoID {
                    Task {
                        do {
                            let info = try await InnerTubeAPI.shared.fetchPlayerInfo(videoId: videoId)
                            videoManager.setVideo(info.video)
                        } catch {
                            print("Failed to fetch video: \(error)")
                        }
                    }
                    return .handled
                }
                return .systemAction
            })
            .task(id: ytAuth.isSignedIn) {
                // Re-fetch the feed and the library when sign-in completes
                // — the cold-launch load fired before auth was restored
                // and left the lists empty.
                if ytAuth.isSignedIn {
                    videoLoader.mode = .subscriptions
                    await store.refresh()
                    await videoLoader.loadAllChannelVideos()
                } else {
                    videoLoader.mode = .recommendations
                    videoLoader.clearSubscriptions()
                    await videoLoader.loadRecommendations()
                }
            }
    }
}