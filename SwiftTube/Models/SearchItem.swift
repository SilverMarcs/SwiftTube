//
//  SearchItem.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 21/06/2025.
//

import Foundation

enum SearchItem: Identifiable, Hashable {
    case video(Video)
    case channel(Channel)
    case playlist(Playlist)
    
    var id: String {
        switch self {
        case .video(let video):
            return "video-\(video.id)"
        case .channel(let channel):
            return "channel-\(channel.id)"
        case .playlist(let playlist):
            return "playlist-\(playlist.id)"
        }
    }
    
    var itemType: SearchItemType {
        switch self {
        case .video:
            return .video
        case .channel:
            return .channel
        case .playlist:
            return .playlist
        }
    }
}

struct Playlist: Identifiable, Hashable {
    let id: String
    let name: String
    let thumbnailURL: URL?
    let videoCount: Int?
    let uploaderName: String?
    let uploaderUrl: String?
    
    init(id: String, name: String, thumbnailURL: URL? = nil, videoCount: Int? = nil, uploaderName: String? = nil, uploaderUrl: String? = nil) {
        self.id = id
        self.name = name
        self.thumbnailURL = thumbnailURL
        self.videoCount = videoCount
        self.uploaderName = uploaderName
        self.uploaderUrl = uploaderUrl
    }
    
    var videoCountText: String? {
        guard let count = videoCount else { return nil }
        return "\(count) videos"
    }
}
