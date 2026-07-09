#if !os(tvOS)
import SwiftUI

/// Sheet shown when a video finishes (iOS/macOS), listing the related "up next"
/// videos in the shared `VideoGridView` so it adapts across platforms/size
/// classes. Tapping a card goes through the standard `PlayVideoButton` flow,
/// which swaps the current video and clears `showUpNext` — dismissing this sheet.
struct UpNextSheet: View {
    @Environment(VideoManager.self) private var manager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VideoGridView(videos: manager.upNextVideos, isGuestAllowed: true, extractsShorts: false)
                .navigationTitle("Up Next")
                .toolbarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .close) { dismiss() }
                    }
                }
        }
    }
}
#endif
