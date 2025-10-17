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
    
    var title: String {
        switch self {
        case .feed: return "Videos"
        case .shorts: return "Shorts"
        case .profile: return "Profile"
        case .search: return "Search"
        }
    }
    
    var systemImage: String {
        switch self {
        case .feed: return "video"
        case .shorts: return "play.rectangle.on.rectangle"
        case .profile: return "person"
        case .search: return "magnifyingglass"
        }
    }
    
    var shortcutKey: String? {
        switch self {
        case .feed: return "1"
        case .shorts: return "2"
        case .profile: return ","
        case .search: return "f"
        }
    }
    
    @ViewBuilder
    var tabView: some View {
        switch self {
        case .feed: FeedView()
        case .shorts: ShortsView()
        case .profile: ProfileView()
        case .search: SearchView()
        }
    }
}
