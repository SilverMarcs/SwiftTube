import SwiftUI

/// A titled horizontal shelf of videos — Cathode's `VideoCard` on FinStream's
/// `SectionContainer` + `HorizontalShelf` paradigm. Data is pre-loaded (by
/// `VideoLoader`); tapping the header (iOS/macOS) or the trailing card (tvOS)
/// pushes `destination` ("see all"). `onReachEnd` fires near the right edge for
/// lazy horizontal pagination.
struct VideoShelf<Destination: View>: View {
    let group: VideoGroup
    var onReachEnd: (() -> Void)? = nil
    @ViewBuilder var destination: () -> Destination

    #if os(tvOS)
    private let cardWidth: CGFloat = 460
    private let spacing: CGFloat = 40
    #else
    private let cardWidth: CGFloat = 300
    private let spacing: CGFloat = 16
    #endif

    var body: some View {
        SectionContainer(isVisible: !group.videos.isEmpty) {
            HorizontalShelf(spacing: spacing) {
                ForEach(Array(group.videos.enumerated()), id: \.element.id) { index, video in
                    VideoCard(video: video)
                        .frame(width: cardWidth)
                        .task {
                            // Prefetch when the 2nd-to-last card appears.
                            if index >= group.videos.count - 2 { onReachEnd?() }
                        }
                }

                #if os(tvOS)
                // tvOS section headers aren't tappable, so "see all" is a trailing card.
                NavigationLink {
                    destination()
                } label: {
                    SeeAllCard()
                        .frame(width: cardWidth, height: cardWidth * 9 / 16)
                }
                .buttonStyle(.card)
                #endif
            }
        } header: {
            #if os(tvOS)
            Text(group.title ?? "")
            #else
            NavigationLink {
                destination()
            } label: {
                HStack(spacing: 4) {
                    Text(group.title ?? "")
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            #endif
        }
    }
}

#if os(tvOS)
private struct SeeAllCard: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.right.circle")
                .font(.system(size: 64, weight: .light))
            Text("See All")
                .font(.headline)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background.secondary, in: .rect(cornerRadius: 12))
    }
}
#endif
