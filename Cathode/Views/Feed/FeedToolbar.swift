import SwiftUI

struct FeedToolbar: View {
    @Environment(VideoLoader.self) private var videoLoader
    @Environment(YTTVAuthManager.self) private var ytAuth

    var body: some View {
        HStack(spacing: 12) {
            if !ytAuth.isSignedIn {
                  Button {} label: {
                      Text("Not signed in")
                  }
            }

            #if !os(tvOS)
            if ytAuth.isSignedIn {
                Button {
                    let target: FeedMode = (videoLoader.mode == .subscriptions) ? .recommendations : .subscriptions
                    Task { await videoLoader.switchTo(target) }
                } label: {
                    Label(
                        videoLoader.mode == .subscriptions ? "Show Recommendations" : "Show Subscriptions",
                        systemImage: videoLoader.mode == .subscriptions ? "sparkles" : "person.crop.rectangle.stack"
                    )
                    .labelStyle(.iconOnly)
                }
            }
            #endif

            RefreshButton { await videoLoader.refreshCurrent() }
        }
    }
}
