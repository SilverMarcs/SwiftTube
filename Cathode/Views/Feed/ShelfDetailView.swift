import SwiftUI

/// "See all" for a Home shelf: the full list via `VideoGridView`, paginating
/// through the shelf's own continuation. Reads the live shelf from `VideoLoader`
/// (shared with the Home shelf) so loading more here also grows it there.
struct ShelfDetailView: View {
    @Environment(VideoLoader.self) private var videoLoader
    let shelfID: VideoGroup.ID
    let title: String

    private var videos: [Video] {
        videoLoader.recommendationRows.first { $0.id == shelfID }?.videos ?? []
    }

    var body: some View {
        VideoGridView(
            videos: videos,
            isGuestAllowed: true,
            onReachEnd: {
                Task { await videoLoader.loadMoreInShelf(shelfID) }
            }
        )
        .platformTopBar(title, titleDisplayMode: .inline)
    }
}
