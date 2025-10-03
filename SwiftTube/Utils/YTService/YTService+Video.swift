//
//  YTService+Video.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 28/09/2025.
//

import Foundation

extension YTService {
    static func fetchVideoDetails(for video: inout Video) async throws {
        let url = URL(string: "\(baseURL)/videos?part=snippet,contentDetails,statistics&id=\(video.id)")!
        
        let response: VideoDetailResponse = try await fetchResponse(from: url)
        
        guard let item = response.items.first else {
            throw APIError.videoNotFound
        }
        
        let duration = item.contentDetails.duration.parseDurationToSeconds()
        video.duration = duration
        video.viewCount = item.statistics.viewCount
        video.likeCount = item.statistics.likeCount
    }
    
    static func fetchVideoDetails(for videos: inout [Video]) async throws {
        // Take only first 50 videos (YouTube API limit)
        let limitedCount = min(videos.count, 50)
        
        let videoIds = videos.prefix(limitedCount).map { $0.id }.joined(separator: ",")
        let url = URL(string: "\(baseURL)/videos?part=snippet,contentDetails,statistics&id=\(videoIds)")!
        
        let response: VideoDetailResponse = try await fetchResponse(from: url)
        
        // Update each video with the fetched details
        for item in response.items {
            if let index = videos.firstIndex(where: { $0.id == item.id }) {
                let duration = item.contentDetails.duration.parseDurationToSeconds()
                videos[index].duration = duration
                videos[index].viewCount = item.statistics.viewCount
                videos[index].likeCount = item.statistics.likeCount
            }
        }
    }
    
    static func fetchVideo(byId id: String) async throws -> Video {
        let url = URL(string: "\(baseURL)/videos?part=snippet,contentDetails,statistics&id=\(id)")!
        
        let response: VideoDetailResponse = try await fetchResponse(from: url)
        
        guard let item = response.items.first else {
            throw APIError.videoNotFound
        }
        
        let channel: Channel
        if let savedChannel = UserDefaultsManager.shared.savedChannels.first(where: { $0.id == item.snippet.channelId }) {
            channel = savedChannel
        } else {
            channel = try await YTService.fetchChannel(byId: item.snippet.channelId)
        }
        
        let duration = item.contentDetails.duration.parseDurationToSeconds()
        
        return Video(
            id: item.id,
            title: item.snippet.title,
            videoDescription: item.snippet.description,
            thumbnailURL: item.snippet.thumbnails.medium.url,
            publishedAt: YTService.isoFormatter.date(from: item.snippet.publishedAt) ?? Date(),
            url: "https://www.youtube.com/watch?v=\(item.id)",
            channel: channel,
            viewCount: item.statistics.viewCount,
            isShort: duration <= 60
        )
    }
}
