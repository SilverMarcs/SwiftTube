import SwiftUI

/// Horizontal rail of Shorts shown atop a `VideoGridView`. Reaching the last card
/// pages the underlying stream (best-effort — a page may add no Shorts).
struct ShortsRail: View {
    let shorts: [Video]
    var onReachEnd: (() -> Void)? = nil

    var body: some View {
        HorizontalShelf(spacing: 12) {
            ForEach(shorts) { video in
                ShortRailCard(video: video)
                    .task {
                        if video.id == shorts.last?.id { onReachEnd?() }
                    }
            }
        }
        .padding(.bottom, 20)
    }
}
