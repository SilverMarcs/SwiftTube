//
//  TabSelection.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 17/10/2025.
//

import SwiftUI

enum TabSelection: String, CaseIterable {
    case feed = "feed"
    case shorts = "shorts"
    case library = "library"
    case search = "search"
    case settings = "settings"
    case channels = "channels"
    case bookmark = "watchLater"
    case history = "history"

#if os(tvOS)
    static let compactTabs: [TabSelection] = [.search, .feed, .channels, .library]
    static let extendedTabs: [TabSelection] = [.search, .feed, .settings]
#else
    static let compactTabs: [TabSelection] = [.search, .feed, .shorts, .channels, .library]
    static let extendedTabs: [TabSelection] = [.search, .feed, .shorts, .settings]
#endif
    static let extendedSubscriptionTabs: [TabSelection] = [.channels]
    static let extendedLibraryTabs: [TabSelection] = [.bookmark, .history]
    static let allCases: [TabSelection] = [.feed, .shorts, .library, .search, .settings, .channels, .bookmark, .history]

    var title: String {
        switch self {
        case .feed: return "Videos"
        case .shorts: return "Shorts"
        case .library: return "Library"
        case .search: return "Search"
        case .settings: return "Settings"
        case .channels: return "Channels"
        case .bookmark: return "Bookmarks"
        case .history: return "History"
        }
    }

    var systemImage: String {
        switch self {
        case .feed: return "video"
        case .shorts: return "play.rectangle.on.rectangle"
        case .library: return "rectangle.stack"
        case .search: return "magnifyingglass"
        case .settings: return "gear"
        case .channels: return "bell"
        case .bookmark: return "bookmark"
        case .history: return "clock"
        }
    }

    var shortcutKey: String? {
        switch self {
        case .feed: return "1"
        case .shorts: return "2"
        case .channels: return "3"
        case .library: return "4"
        case .search: return "f"
        case .settings: return ","
        case .bookmark: return "5"
        case .history: return "6"
        }
    }

    @ViewBuilder
    var tabView: some View {
        switch self {
        case .feed: FeedView()
        case .shorts:
#if os(tvOS)
            EmptyView()
#else
            ShortsView()
#endif
        case .library: ProfileView()
        case .search: SearchView()
        case .settings: SettingsView()
        case .channels: ChannelListView()
        case .bookmark: BookmarkFullView()
        case .history: HistoryFullView()
        }
    }
}
