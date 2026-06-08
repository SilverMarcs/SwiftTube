import SwiftUI

struct VideoDetailMenuView: View {
    let video: Video
    @Environment(LibraryStore.self) private var library

    var body: some View {
        Menu {
            #if !os(tvOS)
            if let url = video.watchURL {
                ShareLink(item: url) {
                    Label("Share Video", systemImage: "square.and.arrow.up")
                }
                .tint(.primary)
            }
            #endif

            Button {
                library.toggleBookmark(video)
            } label: {
                Label(
                    library.isBookmarked(video.id) ? "Remove Bookmark" : "Add Bookmark",
                    systemImage: library.isBookmarked(video.id) ? "bookmark.fill" : "bookmark"
                )
            }
            .tint(.primary)

            #if os(iOS)
            Divider()

            DownloadMenuButton(video: video)
                .tint(.primary)
            #endif
        } label: {
            Image(systemName: "ellipsis")
                .padding(10)
        }
        .glassEffect()
    }
}
