import SwiftUI

/// Card density for the compact-width (iPhone) list. Persisted via `@AppStorage`.
enum VideoListStyle: String, CaseIterable {
    case large, compact

    var title: String {
        switch self {
        case .large: return "Large"
        case .compact: return "Compact"
        }
    }

    var systemImage: String {
        switch self {
        case .large: return "rectangle.grid.1x2"
        case .compact: return "list.bullet"
        }
    }
}

struct VideoGridView<Header: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(YTTVAuthManager.self) private var ytAuth
    #if os(iOS)
    @AppStorage("videoListStyle") private var listStyle: VideoListStyle = .large
    #endif

    let videos: [Video]
    var showChannelLinkInContextMenu: Bool = true
    var showsBookmarkIcon: Bool = true
    var isGuestAllowed: Bool = false
    /// Called when the user reaches the last card. Wire this to a paginator
    /// (e.g. `VideoLoader.loadMore`) for infinite scroll.
    var onReachEnd: (() -> Void)? = nil
    /// Called by pull-to-refresh and the toolbar refresh button. When `nil`,
    /// neither affordance is shown.
    var onRefresh: (() async -> Void)? = nil
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

    /// The list row for the compact-width layout. On iPhone it honors the
    /// `listStyle` toggle (Big → `VideoCard`, Compact → `CompactVideoCard`).
    @ViewBuilder
    private func listRow(for video: Video) -> some View {
        #if os(iOS)
        if listStyle == .compact {
            CompactVideoCard(video: video)
        } else {
            VideoCard(video: video, showChannelLink: showChannelLinkInContextMenu, showsBookmarkIcon: showsBookmarkIcon)
        }
        #else
        VideoCard(video: video, showChannelLink: showChannelLinkInContextMenu, showsBookmarkIcon: showsBookmarkIcon)
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
                                    .task {
                                        if video.id == videos.last?.id { onReachEnd?() }
                                    }
                            }
                        }
                    }
                    .scenePadding(.horizontal)
                    .scenePadding(.bottom)
                }
                #if os(macOS)
                .contentMargins(.top, 10)
                #endif
                .modifier(RefreshableModifier(onRefresh: onRefresh))
            } else {
                List {
                    header()
                        #if !os(tvOS)
                        .listRowSeparator(.hidden)
                        #endif
                        .listRowInsets(.horizontal, 0)
                        .listRowInsets(.vertical, 0)
                    ForEach(videos) { video in
                        listRow(for: video)
                            #if os(iOS)
                            // Compact rows show a divider only below each row (not above);
                            // the Large style uses full cards, so no separators.
                            .listRowSeparator(.hidden, edges: .top)
                            .listRowSeparator(listStyle == .compact ? .visible : .hidden, edges: .bottom)
                            #elseif os(macOS)
                            .listRowSeparator(.hidden)
                            #endif
                            #if os(iOS)
                            .listRowInsets(.vertical, listStyle == .compact ? 15 : 5)
                            .listRowInsets(.horizontal, listStyle == .compact ? 15 : 10)
                            #else
                            .listRowInsets(.vertical, 5)
                            .listRowInsets(.horizontal, 10)
                            #endif
                            .task {
                                if video.id == videos.last?.id { onReachEnd?() }
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
        .toolbar {
            #if os(iOS)
            // iPhone only — iPad/macOS/tvOS use the grid layout, no density toggle.
            if Device.isIPhone {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Picker("Layout", selection: $listStyle) {
                            ForEach(VideoListStyle.allCases, id: \.self) { style in
                                Label(style.title, systemImage: style.systemImage).tag(style)
                            }
                        }
                    } label: {
                        Label("Layout", systemImage: listStyle.systemImage)
                    }
                }
            }
            #endif
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
        onReachEnd: (() -> Void)? = nil,
        onRefresh: (() async -> Void)? = nil
    ) {
        self.videos = videos
        self.showChannelLinkInContextMenu = showChannelLinkInContextMenu
        self.showsBookmarkIcon = showsBookmarkIcon
        self.isGuestAllowed = isGuestAllowed
        self.onReachEnd = onReachEnd
        self.onRefresh = onRefresh
        self.header = { EmptyView() }
    }
}
