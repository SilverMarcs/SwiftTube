import SwiftUI

/// Share + bookmark actions for a video, as a reusable toolbar group.
/// Used by both the iOS detail toolbar and the macOS player inspector toolbar
/// so the two buttons are defined once.
struct VideoActionsToolbarContent: ToolbarContent {
    let video: Video
    @Environment(LibraryStore.self) private var library

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if let url = video.watchURL {
                ShareLink(item: url) {
                    Label("Share Video", systemImage: "square.and.arrow.up")
                }
            }

            Button {
                library.toggleBookmark(video)
            } label: {
                Label(
                    library.isBookmarked(video.id) ? "Remove Bookmark" : "Add Bookmark",
                    systemImage: library.isBookmarked(video.id) ? "bookmark.fill" : "bookmark"
                )
            }
        }
    }
}
