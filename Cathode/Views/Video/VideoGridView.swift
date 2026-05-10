import SwiftUI

struct VideoGridView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let videos: [Video]
    var showChannelLinkInContextMenu: Bool = true
    var showsWatchLaterIcon: Bool = true

    private var gridColumns: [GridItem] {
        #if os(tvOS)
        [GridItem(.adaptive(minimum: 420, maximum: 560), spacing: gridSpacing, alignment: .top)]
        #else
        [GridItem(.adaptive(minimum: 240, maximum: 420), spacing: gridSpacing, alignment: .top)]
        #endif
    }

    private var gridSpacing: CGFloat {
        #if os(tvOS)
        30
        #else
        10
        #endif
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                ScrollView {
                    LazyVGrid(columns: gridColumns, spacing: gridSpacing) {
                        ForEach(videos) { video in
                            VideoCard(video: video, showChannelLink: showChannelLinkInContextMenu, showsWatchLaterIcon: showsWatchLaterIcon)
                        }
                    }
                    .scenePadding(.horizontal)
                    .scenePadding(.bottom)
                }
                #if os(macOS)
                .contentMargins(.top, 10)
                #endif
            } else {
                List(videos) { video in
                    VideoCard(video: video, showChannelLink: showChannelLinkInContextMenu, showsWatchLaterIcon: showsWatchLaterIcon)
                        #if !os(tvOS)
                        .listRowSeparator(.hidden)
                        #endif
                        .listRowInsets(.vertical, 5)
                        .listRowInsets(.horizontal, 10)
                }
            }
        }
        .overlay {
            if videos.isEmpty {
                UniversalProgressView()
            }
        }
    }
}
