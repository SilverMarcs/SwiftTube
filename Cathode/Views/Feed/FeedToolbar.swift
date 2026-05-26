import SwiftUI

struct FeedToolbar: View {
    @Environment(VideoLoader.self) private var videoLoader

    var body: some View {
        #if !os(tvOS)
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
        #endif

        RefreshButton { await videoLoader.refreshCurrent() }
    }
}
