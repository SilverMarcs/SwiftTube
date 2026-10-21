import SwiftUI

struct VideoShelf: View {
    let group: VideoGroup
    var onReachEnd: (() -> Void)?

    #if os(tvOS)
    private let cardWidth: CGFloat = 460
    private let spacing: CGFloat = 40
    #else
    private let cardWidth: CGFloat = 300
    private let spacing: CGFloat = 16
    #endif

    var body: some View {
        SectionContainer {
            HorizontalShelf(spacing: spacing) {
                ForEach(group.videos.enumerated(), id: \.element.id) { index, video in
                    VideoCard(video: video)
                        .frame(width: cardWidth)
                        .task {
                            if index >= group.videos.count - 2 { onReachEnd?() }
                        }
                }
                #if os(tvOS)
                NavigationLink(value: group.id) {
                    SeeAllCard()
                        .frame(width: cardWidth, height: cardWidth * 9 / 16)
                }
                .buttonStyle(.card)
                #endif
            }
        } header: {
            #if os(tvOS)
            Text(group.title ?? "Recommended")
            #else
            NavigationLink(value: group.id) {
                HStack {
                    Text(group.title ?? "Recommended")
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            #endif
        }
    }
}
