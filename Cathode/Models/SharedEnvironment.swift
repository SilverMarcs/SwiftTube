import SwiftUI

struct SharedEnvironment: ViewModifier {
    let videoLoader: VideoLoader
    let videoManager: VideoManager
    let store: LibraryStore
    let ytAuth: YTTVAuthManager

    func body(content: Content) -> some View {
        content
            .environment(videoLoader)
            .environment(videoManager)
            .environment(store)
            .environment(ytAuth)
            // .accentColor(.accent)
            .environment(\.openURL, OpenURLAction { url in
                if let videoId = url.youtubeVideoID {
                    videoManager.setVideo(Video(id: videoId, title: "", channelTitle: ""))
                    return .handled
                }
                return .systemAction
            })
            .task(id: ytAuth.isSignedIn) {
                // Re-fetch the feed and the library when sign-in completes
                // — the cold-launch load fired before auth was restored
                // and left the lists empty.
                if ytAuth.isSignedIn {
                    await store.refresh()
                    await videoLoader.loadAllChannelVideos()
                } else {
                    videoLoader.clearSubscriptions()
                }
            }
    }
}