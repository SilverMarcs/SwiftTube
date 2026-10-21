import SwiftUI

struct VideoGridView<Header: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(YTTVAuthManager.self) private var ytAuth

    let videos: [Video]
    var showChannelLinkInContextMenu: Bool = true
    var showsBookmarkIcon: Bool = true
    var isGuestAllowed: Bool = false
    /// When `true` (default), any Shorts in `videos` are pulled into a horizontal
    /// rail on top and the vertical grid shows only non-Shorts. Turn off where the
    /// order is meaningful (e.g. the Up Next queue).
    var extractsShorts: Bool = true
    /// Called when the user reaches the last card. Wire this to a paginator
    /// (e.g. `VideoLoader.loadMore`) for infinite scroll.
    var onReachEnd: (() -> Void)? = nil
    /// Called by pull-to-refresh and the toolbar refresh button. When `nil`,
    /// neither affordance is shown.
    var onRefresh: (() async -> Void)? = nil
    @ViewBuilder var header: () -> Header

    /// tvOS uses the vertical grid layout with focus-scaled landscape cards; a
    /// portrait Shorts rail doesn't fit that model, so we never extract there and
    /// let Shorts render inline in the grid instead.
    private var shortsExtractionEnabled: Bool {
        #if os(tvOS)
        false
        #else
        extractsShorts
        #endif
    }

    private var shorts: [Video] {
        shortsExtractionEnabled ? videos.filter(\.isShort) : []
    }

    /// The videos shown in the vertical grid/list — everything not pulled into the
    /// Shorts rail.
    private var mainVideos: [Video] {
        shortsExtractionEnabled ? videos.filter { !$0.isShort } : videos
    }

    private var usesGridLayout: Bool {
        #if os(tvOS)
        true
        #else
        horizontalSizeClass == .regular
        #endif
    }

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
            if usesGridLayout {
                ScrollView {
                    LazyVStack(spacing: gridSpacing) {
                        // The Shorts rail supplies its own leading gutter.
                        if !shorts.isEmpty {
                            ShortsRail(shorts: shorts, onReachEnd: onReachEnd)
                        }
                        header()
                            .scenePadding(.horizontal)
                        LazyVGrid(columns: gridColumns, spacing: gridSpacing) {
                            ForEach(mainVideos) { video in
                                VideoCard(video: video, showChannelLink: showChannelLinkInContextMenu, showsBookmarkIcon: showsBookmarkIcon)
                                    .task {
                                        if video.id == mainVideos.last?.id { onReachEnd?() }
                                    }
                            }
                        }
                        .scenePadding(.horizontal)
                    }
                    .scenePadding(.bottom)
                }
                #if os(macOS)
                .contentMargins(.top, 10)
                #endif
                .modifier(RefreshableModifier(onRefresh: onRefresh))
            } else {
                List {
                    if !shorts.isEmpty {
                        ShortsRail(shorts: shorts, onReachEnd: onReachEnd)
                            #if !os(tvOS)
                            .listRowSeparator(.hidden)
                            #endif
                            .listRowInsets(.horizontal, 0)
                            .listRowInsets(.vertical, 0)
                    }
                    header()
                        #if !os(tvOS)
                        .listRowSeparator(.hidden)
                        #endif
                        .listRowInsets(.horizontal, 0)
                        .listRowInsets(.vertical, 0)
                    ForEach(mainVideos) { video in
                        VideoCard(video: video, showChannelLink: showChannelLinkInContextMenu, showsBookmarkIcon: showsBookmarkIcon)
                            #if !os(tvOS)
                            .listRowSeparator(.hidden)
                            #endif
                            .listRowInsets(.vertical, 5)
                            .listRowInsets(.horizontal, 10)
                            .task {
                                if video.id == mainVideos.last?.id { onReachEnd?() }
                            }
                    }
                }
                .listStyle(.plain)
                .modifier(RefreshableModifier(onRefresh: onRefresh))
            }
        }
        .overlay {
            if videos.isEmpty {
                if !isGuestAllowed && !ytAuth.isSignedIn {
                    ContentUnavailableView(
                        "Sign in to YouTube",
                        systemImage: "person.crop.circle.badge.exclamationmark",
                        description: Text("Sign in from Library → Settings to load your feed.")
                    )
                    #if os(tvOS)
                    .focusable(true)
                    #endif
                } else {
                    UniversalProgressView()
                        #if os(tvOS)
                        .focusable(true)
                        #endif
                }
            }
        }
        #if os(tvOS)
        .focusSection()
        #endif
    }
}

private struct RefreshableModifier: ViewModifier {
    let onRefresh: (() async -> Void)?

    func body(content: Content) -> some View {
        #if os(tvOS)
        content
        #else
        if let onRefresh {
            content.refreshable { await onRefresh() }
        } else {
            content
        }
        #endif
    }
}

extension VideoGridView where Header == EmptyView {
    init(
        videos: [Video],
        showChannelLinkInContextMenu: Bool = true,
        showsBookmarkIcon: Bool = true,
        isGuestAllowed: Bool = false,
        extractsShorts: Bool = true,
        onReachEnd: (() -> Void)? = nil,
        onRefresh: (() async -> Void)? = nil
    ) {
        self.videos = videos
        self.showChannelLinkInContextMenu = showChannelLinkInContextMenu
        self.showsBookmarkIcon = showsBookmarkIcon
        self.isGuestAllowed = isGuestAllowed
        self.extractsShorts = extractsShorts
        self.onReachEnd = onReachEnd
        self.onRefresh = onRefresh
        self.header = { EmptyView() }
    }
}
