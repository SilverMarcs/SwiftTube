//
//  YTService+Channel.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 28/09/2025.
//

import Foundation

extension YTService {
    static func fetchChannel(forHandle handle: String) async throws -> Channel {
        let encoded = handle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? handle
        let url = URL(string: "\(baseURL)/channels?part=snippet,contentDetails,statistics&forHandle=\(encoded)")!
        
        let response: ChannelResponse = try await fetchOAuthResponse(from: url)
        
        guard let item = response.items.first else {
            throw APIError.channelNotFound
        }
        
        return Channel(
            id: item.id,
            title: item.snippet.title,
            channelDescription: item.snippet.description,
            thumbnailURL: item.snippet.thumbnails.medium.url,
            uploadsPlaylistId: item.contentDetails.relatedPlaylists.uploads,
            viewCount: UInt64(item.statistics.viewCount) ?? 0,
            subscriberCount: UInt64(item.statistics.subscriberCount) ?? 0
        )
    }
    
    static func fetchChannel(byId channelId: String) async throws -> Channel {
        let url = URL(string: "\(baseURL)/channels?part=snippet,contentDetails,statistics&id=\(channelId)")!
        
        let response: ChannelResponse = try await fetchOAuthResponse(from: url)
        
        guard let item = response.items.first else {
            throw APIError.channelNotFound
        }
        
        return Channel(
            id: item.id,
            title: item.snippet.title,
            channelDescription: item.snippet.description,
            thumbnailURL: item.snippet.thumbnails.medium.url,
            uploadsPlaylistId: item.contentDetails.relatedPlaylists.uploads,
            viewCount: UInt64(item.statistics.viewCount) ?? 0,
            subscriberCount: UInt64(item.statistics.subscriberCount) ?? 0
        )
    }
}