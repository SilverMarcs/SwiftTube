//
//  SearchItemResponse.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 21/06/2025.
//

import Foundation

struct SearchItemResponse: Codable {
    let url: String?
    let type: String?
    let title: String?
    let name: String?
    let thumbnail: String?
    
    // Video fields
    let uploaderName: String?
    let uploaderUrl: String?
    let uploaderAvatar: String?
    let uploaderVerified: Bool?
    let duration: Int?
    let isShort: Bool?
    let views: Int?
    let uploaded: Int?
    let uploadedDate: String?
    let shortDescription: String?
    
    // Channel fields
    let subscribers: Int?
    let subscriberCount: Int?
    let description: String?
    let verified: Bool?
    let avatar: String?
    
    // Playlist fields
    let playlistType: String?
    let videos: Int?
    
    var itemType: SearchItemType {
        if let type = type {
            return SearchItemType(rawValue: type) ?? .unknown
        }
        
        if let url = url {
            if url.contains("/channel/") || url.contains("/c/") || url.contains("/user/") {
                return .channel
            } else if url.contains("/playlist") {
                return .playlist
            } else if url.contains("/watch") {
                return .video
            }
        }
        
        return .unknown
    }
    
    func toChannel() -> Channel? {
        guard itemType == .channel else { return nil }
        
        let channelId = extractChannelId(from: url ?? "")
        let channelName = name ?? title ?? ""
        let thumbnailURL = thumbnail.flatMap { URL(string: $0) }
        let subscribersCount = subscribers
        
        return Channel(
            id: channelId,
            name: channelName,
            thumbnailURL: thumbnailURL,
            subscribersCount: subscribersCount,
            description: description,
            verified: verified ?? false
        )
    }
    
    func toVideo() -> Video? {
        guard itemType == .video else { return nil }
        
        let videoUrl = url ?? ""
        let videoTitle = title ?? ""
        let uploaderName = uploaderName ?? ""
        let duration = duration ?? 0
        let views = views ?? 0
        
        return Video(
            url: videoUrl,
            title: videoTitle,
            duration: duration,
            type: type,
            thumbnail: thumbnail,
            uploaded: uploaded.flatMap { Double($0) } ?? 0,
            uploaderVerified: uploaderVerified ?? false,
            uploaderName: uploaderName,
            uploaderUrl: uploaderUrl,
            uploaderAvatar: uploaderAvatar,
            isShort: isShort ?? (duration < 61),
            views: views
        )
    }
    
    func toPlaylist() -> Playlist? {
        guard itemType == .playlist else { return nil }
        
        let playlistId = extractPlaylistId(from: url ?? "")
        let playlistName = name ?? title ?? ""
        let thumbnailURL = thumbnail.flatMap { URL(string: $0) }
        
        return Playlist(
            id: playlistId,
            name: playlistName,
            thumbnailURL: thumbnailURL,
            videoCount: videos,
            uploaderName: uploaderName,
            uploaderUrl: uploaderUrl
        )
    }
    
    func toSearchItem() -> SearchItem? {
        switch itemType {
        case .video:
            if let video = toVideo() {
                return .video(video)
            }
        case .channel:
            if let channel = toChannel() {
                return .channel(channel)
            }
        case .playlist:
            if let playlist = toPlaylist() {
                return .playlist(playlist)
            }
        case .unknown:
            return nil
        }
        return nil
    }
    
    private func extractPlaylistId(from url: String) -> String {
        if url.contains("?list=") {
            return url.components(separatedBy: "?list=").last ?? url
        } else if url.contains("/playlist") {
            return url.components(separatedBy: "/playlist/").last ?? url
        }
        return url
    }
    
    private func extractChannelId(from url: String) -> String {
        if url.contains("/channel/") {
            return url.components(separatedBy: "/channel/").last ?? url
        } else if url.contains("/c/") {
            return url.components(separatedBy: "/c/").last ?? url
        } else if url.contains("/user/") {
            return url.components(separatedBy: "/user/").last ?? url
        }
        return url
    }
    
    private func extractVideoId(from url: String) -> String {
        if url.contains("?v=") {
            return url.components(separatedBy: "?v=").last ?? url
        }
        return url
    }
}

enum SearchItemType: String, Codable {
    case video = "stream"
    case channel = "channel" 
    case playlist = "playlist"
    case unknown
}
