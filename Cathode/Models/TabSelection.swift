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
    case profile = "profile"
    case search = "search"
    case settings = "settings"
    case channels = "channels"
    case watchLater = "watchLater"
    case history = "history"

    static let compactTabs: [TabSelection] = [.search, .feed, .shorts, .profile, .settings]
    static let extendedTabs: [TabSelection] = [.search, .feed, .shorts, .settings]
    static let extendedSubscriptionTabs: [TabSelection] = [.channels]
    static let extendedLibraryTabs: [TabSelection] = [.watchLater, .history]
    static let allCases: [TabSelection] = [.feed, .shorts, .profile, .search, .settings, .channels, .watchLater, .history]

    var title: String {
        switch self {
        case .feed: return "Videos"
        case .shorts: return "Shorts"
        case .profile: return "Profile"
        case .search: return "Search"
        case .settings: return "Settings"
        case .channels: return "Channels"
        case .watchLater: return "Watch Later"
        case .history: return "History"
        }
    }

    var systemImage: String {
        switch self {
        case .feed: return "video"
        case .shorts: return "play.rectangle.on.rectangle"
        case .profile: return "person"
        case .search: return "magnifyingglass"
        case .settings: return "gear"
        case .channels: return "bell"
        case .watchLater: return "bookmark"
        case .history: return "clock"
        }
    }

    var shortcutKey: String? {
        switch self {
        case .feed: return "1"
        case .shorts: return "2"
        case .profile: return "3"
        case .search: return "f"
        case .settings: return ","
        case .channels: return "4"
        case .watchLater: return "5"
        case .history: return "6"
        }
    }

    @ViewBuilder
    var tabView: some View {
        switch self {
        case .feed: FeedView()
        case .shorts: ShortsView()
        case .profile: ProfileView()
        case .search: SearchView()
        case .settings: SettingsView()
        case .channels: ChannelListView()
        case .watchLater: WatchLaterFullView()
        case .history: HistoryFullView()
        }
    }
}
