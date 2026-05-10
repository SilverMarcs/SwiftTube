import SwiftUI

struct VideoGridView<Header: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let videos: [Video]
    var showChannelLinkInContextMenu: Bool = true
    var showsBookmarkIcon: Bool = true
    @ViewBuilder var header: () -> Header

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
                    LazyVStack(spacing: gridSpacing) {
                        header()
                        LazyVGrid(columns: gridColumns, spacing: gridSpacing) {
                            ForEach(videos) { video in
                                VideoCard(video: video, showChannelLink: showChannelLinkInContextMenu, showsBookmarkIcon: showsBookmarkIcon)
                            }
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
                    VideoCard(video: video, showChannelLink: showChannelLinkInContextMenu, showsBookmarkIcon: showsBookmarkIcon)
                        #if !os(tvOS)
                        .listRowSeparator(.hidden)
                        #endif
                        .listRowInsets(.vertical, 5)
                        .listRowInsets(.horizontal, 10)
                }
                .listStyle(.plain)
            }
        }
        .overlay {
            if videos.isEmpty {
                UniversalProgressView()
            }
        }
    }
}

extension VideoGridView where Header == EmptyView {
    init(videos: [Video], showChannelLinkInContextMenu: Bool = true, showsBookmarkIcon: Bool = true) {
        self.videos = videos
        self.showChannelLinkInContextMenu = showChannelLinkInContextMenu
        self.showsBookmarkIcon = showsBookmarkIcon
        self.header = { EmptyView() }
    }
}
