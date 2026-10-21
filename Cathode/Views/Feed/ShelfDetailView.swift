import SwiftUI

struct ShelfDetailView: View {
    @Environment(VideoLoader.self) private var videoLoader
    let shelfID: VideoGroup.ID

    private var shelf: VideoGroup? {
        videoLoader.recommendationRows.first { $0.id == shelfID }
    }

    var body: some View {
        VideoGridView(
            videos: shelf?.videos ?? [],
            isGuestAllowed: true,
            onReachEnd: { Task { await videoLoader.loadMoreInShelf(shelfID) } }
        )
        .platformTopBar(shelf?.title ?? "Recommended", titleDisplayMode: .inline)
    }
}
