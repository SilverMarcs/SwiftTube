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
        
        let response: ChannelResponse = try await fetchResponse(from: url)
        
        guard let item = response.items.first else {
            throw APIError.channelNotFound
        }
        
        return Channel(
            id: item.id,
            title: item.snippet.title,
            channelDescription: item.snippet.description,
            thumbnailURL: item.snippet.thumbnails.medium.url,
            viewCount: UInt64(item.statistics.viewCount) ?? 0,
            subscriberCount: UInt64(item.statistics.subscriberCount) ?? 0
        )
    }
    
    static func fetchChannel(byId channelId: String) async throws -> Channel {
        let url = URL(string: "\(baseURL)/channels?part=snippet,contentDetails,statistics&id=\(channelId)")!
        
        let response: ChannelResponse = try await fetchResponse(from: url)
        
        guard let item = response.items.first else {
            throw APIError.channelNotFound
        }
        
        return Channel(
            id: item.id,
            title: item.snippet.title,
            channelDescription: item.snippet.description,
            thumbnailURL: item.snippet.thumbnails.medium.url,
            viewCount: UInt64(item.statistics.viewCount) ?? 0,
            subscriberCount: UInt64(item.statistics.subscriberCount) ?? 0
        )
    }
    
    static func fetchChannels(byIds channelIds: [String]) async throws -> [Channel] {
        guard !channelIds.isEmpty else { return [] }

        var aggregated: [Channel] = []
        let chunkSize = 50
        var currentIndex = 0

        while currentIndex < channelIds.count {
            let endIndex = min(currentIndex + chunkSize, channelIds.count)
            let chunk = Array(channelIds[currentIndex..<endIndex])
            currentIndex = endIndex

            let idList = chunk.joined(separator: ",")
            let url = URL(string: "\(baseURL)/channels?part=snippet,contentDetails,statistics&id=\(idList)")!
            let response: ChannelResponse = try await fetchResponse(from: url)

            let channels = response.items.map { item in
                Channel(
                    id: item.id,
                    title: item.snippet.title,
                    channelDescription: item.snippet.description,
                    thumbnailURL: item.snippet.thumbnails.medium.url,
                    viewCount: UInt64(item.statistics.viewCount) ?? 0,
                    subscriberCount: UInt64(item.statistics.subscriberCount) ?? 0
                )
            }

            aggregated.append(contentsOf: channels)
        }

        return aggregated
    }
}
