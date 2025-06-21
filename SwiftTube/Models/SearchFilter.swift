//
//  SearchFilter.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 21/06/2025.
//

import Foundation

enum SearchFilter: String, CaseIterable {
    case videos = "videos"
    case channels = "channels"
    case playlists = "playlists"
    
    var displayName: String {
        switch self {
        case .videos:
            return "Videos"
        case .channels:
            return "Channels"
        case .playlists:
            return "Playlists"
        }
    }
    
    var iconName: String {
        switch self {
        case .videos:
            return "video"
        case .channels:
            return "person.2"
        case .playlists:
            return "list.bullet.rectangle"
        }
    }
}
