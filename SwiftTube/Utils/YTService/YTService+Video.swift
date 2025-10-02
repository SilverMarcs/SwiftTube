//
//  YTService+Video.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 28/09/2025.
//

import Foundation

extension YTService {
    static func fetchVideoDetails(for video: Video) async throws {
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
    
    static func fetchVideoDetails(for videos: [Video]) async throws {
        // Split into chunks of 50 (YouTube API limit)
        let chunks = videos.chunked(into: 50)
        
        for chunk in chunks {
            let videoIds = chunk.map { $0.id }.joined(separator: ",")
            let url = URL(string: "\(baseURL)/videos?part=snippet,contentDetails,statistics&id=\(videoIds)")!
            
            let response: VideoDetailResponse = try await fetchResponse(from: url)
            
            // Update each video with the fetched details
            for item in response.items {
                if let video = chunk.first(where: { $0.id == item.id }) {
                    let duration = item.contentDetails.duration.parseDurationToSeconds()
                    video.duration = duration
                    video.viewCount = item.statistics.viewCount
                    video.likeCount = item.statistics.likeCount
                }
            }
        }
    }
    
    static func fetchVideo(byId id: String) async throws -> Video {
        let url = URL(string: "\(baseURL)/videos?part=snippet,contentDetails,statistics&id=\(id)")!
        
        let response: VideoDetailResponse = try await fetchResponse(from: url)
        
        guard let item = response.items.first else {
            throw APIError.videoNotFound
        }
        
        let channel = try await YTService.fetchChannel(byId: item.snippet.channelId)
        
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
