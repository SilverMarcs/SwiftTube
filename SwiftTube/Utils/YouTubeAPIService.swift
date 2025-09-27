//
//  YouTubeAPIService.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 27/09/2025.
//

import Foundation

enum YouTubeAPIService {
    static let baseURL = "https://www.googleapis.com/youtube/v3"
    
    static var apiKey: String? {
        UserDefaults.standard.string(forKey: "youtubeAPIKey")
    }
    
    static func fetchChannelItem(forHandle handle: String) async throws -> ChannelItem {
        guard let apiKey = apiKey else {
            throw APIError.invalidAPIKey
        }
        
        let encoded = handle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? handle
        let url = URL(string: "\(baseURL)/channels?part=snippet,contentDetails&forHandle=\(encoded)&key=\(apiKey)")!
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(ChannelResponse.self, from: data)
        
        guard let item = response.items.first else {
            throw APIError.channelNotFound
        }
        
        return item
    }
    
    static func fetchChannelItem(byId channelId: String) async throws -> ChannelItem {
        guard let apiKey = apiKey else {
            throw APIError.invalidAPIKey
        }
        
        let url = URL(string: "\(baseURL)/channels?part=snippet,contentDetails&id=\(channelId)&key=\(apiKey)")!
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(ChannelResponse.self, from: data)
        
        guard let item = response.items.first else {
            throw APIError.channelNotFound
        }
        
        return item
    }
    
    static func fetchVideoDetailItem(for videoId: String) async throws -> VideoDetailItem {
        guard let apiKey = apiKey else {
            throw APIError.invalidAPIKey
        }
        
        let url = URL(string: "\(baseURL)/videos?part=snippet,contentDetails,statistics&id=\(videoId)&key=\(apiKey)")!
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(VideoDetailResponse.self, from: data)
        
        guard let item = response.items.first else {
            throw APIError.videoNotFound
        }
        
        return item
    }
}
