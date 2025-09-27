//
//  YouTubeAPIService.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 27/09/2025.
//

import Foundation

enum YTService {
    static let baseURL = "https://www.googleapis.com/youtube/v3"
    
    static var apiKey: String? {
        UserDefaults.standard.string(forKey: "youtubeAPIKey")
    }
    
    private static func fetchResponse<T: Decodable>(from url: URL) async throws -> T {
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    private static func parseDurationToSeconds(_ isoDuration: String) -> Int {
        let pattern = "PT(?:(\\d+)H)?(?:(\\d+)M)?(?:(\\d+)S)?"
        let regex = try! NSRegularExpression(pattern: pattern)
        let matches = regex.firstMatch(in: isoDuration, range: NSRange(isoDuration.startIndex..., in: isoDuration))
        
        let hours = matches?.range(at: 1).location != NSNotFound ? 
            Int(String(isoDuration[Range(matches!.range(at: 1), in: isoDuration)!])) ?? 0 : 0
        let minutes = matches?.range(at: 2).location != NSNotFound ? 
            Int(String(isoDuration[Range(matches!.range(at: 2), in: isoDuration)!])) ?? 0 : 0
        let seconds = matches?.range(at: 3).location != NSNotFound ? 
            Int(String(isoDuration[Range(matches!.range(at: 3), in: isoDuration)!])) ?? 0 : 0
        
        return hours * 3600 + minutes * 60 + seconds
    }
    
    static func fetchChannel(forHandle handle: String) async throws -> Channel {
        guard let apiKey = apiKey else {
            throw APIError.invalidAPIKey
        }
        
        let encoded = handle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? handle
        let url = URL(string: "\(baseURL)/channels?part=snippet,contentDetails&forHandle=\(encoded)&key=\(apiKey)")!
        
        let response: ChannelResponse = try await fetchResponse(from: url)
        
        guard let item = response.items.first else {
            throw APIError.channelNotFound
        }
        
        return Channel(
            id: item.id,
            title: item.snippet.title,
            channelDescription: item.snippet.description,
            thumbnailURL: item.snippet.thumbnails.medium.url,
            uploadsPlaylistId: item.contentDetails.relatedPlaylists.uploads
        )
    }
    
    static func fetchChannel(byId channelId: String) async throws -> Channel {
        guard let apiKey = apiKey else {
            throw APIError.invalidAPIKey
        }
        
        let url = URL(string: "\(baseURL)/channels?part=snippet,contentDetails&id=\(channelId)&key=\(apiKey)")!
        
        let response: ChannelResponse = try await fetchResponse(from: url)
        
        guard let item = response.items.first else {
            throw APIError.channelNotFound
        }
        
        return Channel(
            id: item.id,
            title: item.snippet.title,
            channelDescription: item.snippet.description,
            thumbnailURL: item.snippet.thumbnails.medium.url,
            uploadsPlaylistId: item.contentDetails.relatedPlaylists.uploads
        )
    }
    
    static func fetchVideoDetails(for video: Video) async throws {
        guard let apiKey = apiKey else {
            throw APIError.invalidAPIKey
        }
        
        let url = URL(string: "\(baseURL)/videos?part=snippet,contentDetails,statistics&id=\(video.id)&key=\(apiKey)")!
        
        let response: VideoDetailResponse = try await fetchResponse(from: url)
        
        guard let item = response.items.first else {
            throw APIError.videoNotFound
        }
        
        video.duration = parseDurationToSeconds(item.contentDetails.duration)
        video.viewCount = item.statistics.viewCount
        video.likeCount = item.statistics.likeCount
        video.commentCount = item.statistics.commentCount
        video.definition = item.contentDetails.definition.uppercased()
        video.caption = item.contentDetails.caption == "true"
        video.updatedAt = Date()
    }
}
