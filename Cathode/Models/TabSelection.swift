//
//  TabSelection.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 17/10/2025.
//

import SwiftUI

enum TabSelection: String {
    case home = "home"
    case shorts = "shorts"
    case library = "library"
    case search = "search"
    case settings = "settings"
    case channels = "channels"
    case bookmark = "watchLater"
    case history = "history"

    // The UI picks one of two layouts from the horizontal size class:
    //   • compact width (iPhone)              → a flat bottom TAB BAR: `tabBarTabs`
    //   • regular width (iPad / macOS / tvOS) → a SIDEBAR: `sidebarTabs` on top,
    //                                           with the grouped `sidebar*` sections below.

    /// Bottom tab bar (iPhone). Home leads; Search is the trailing `.search`-role tab.
    static let tabBarTabs: [TabSelection] = [.home, .shorts, .channels, .library, .search]

    /// Sidebar primary items (iPad / macOS / tvOS). Search pinned to the top.
    static let sidebarTabs: [TabSelection] = {
        #if os(tvOS)
        [.search, .home, .settings]            // Shorts doesn't exist on tvOS
        #else
        [.search, .home, .shorts, .settings]
        #endif
    }()

    /// Grouped sidebar sections (regular width only).
    static let sidebarSubscriptionTabs: [TabSelection] = [.channels]
    static let sidebarLibraryTabs: [TabSelection] = [.bookmark, .history]

    /// Menu-bar / keyboard-shortcut commands (macOS + iPad).
    static let commandTabs: [TabSelection] = [.home, .shorts, .channels, .library, .search, .settings, .bookmark, .history]

    var title: String {
        switch self {
        case .home: return "Videos"
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
        case .home: return "video"
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
        case .home: return "1"
        case .shorts: return "3"
        case .channels: return "4"
        case .library: return "5"
        case .search: return "f"
        case .settings: return ","
        case .bookmark: return "6"
        case .history: return "7"
        }
    }

    @ViewBuilder
    var tabView: some View {
        switch self {
        case .home: HomeView()
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
