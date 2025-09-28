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
        
        let response: VideoDetailResponse = try await fetchOAuthResponse(from: url)
        
        guard let item = response.items.first else {
            throw APIError.videoNotFound
        }
        
        let duration = item.contentDetails.duration.parseDurationToSeconds()
        video.duration = duration
        video.isShort = duration <= 120 // Videos 120 seconds or less are considered shorts
        video.viewCount = item.statistics.viewCount
        video.likeCount = item.statistics.likeCount
        video.commentCount = item.statistics.commentCount
        video.definition = item.contentDetails.definition.uppercased()
        video.caption = item.contentDetails.caption == "true"
        video.updatedAt = Date()
    }
    
    static func fetchVideoDetails(for videos: [Video]) async throws {
        // Split into chunks of 50 (YouTube API limit)
        let chunks = videos.chunked(into: 50)
        
        for chunk in chunks {
            let videoIds = chunk.map { $0.id }.joined(separator: ",")
            let url = URL(string: "\(baseURL)/videos?part=snippet,contentDetails,statistics&id=\(videoIds)")!
            
            let response: VideoDetailResponse = try await fetchOAuthResponse(from: url)
            
            // Update each video with the fetched details
            for item in response.items {
                if let video = chunk.first(where: { $0.id == item.id }) {
                    let duration = item.contentDetails.duration.parseDurationToSeconds()
                    video.duration = duration
                    video.isShort = duration <= 120 // Videos 120 seconds or less are considered shorts
                    video.viewCount = item.statistics.viewCount
                    video.likeCount = item.statistics.likeCount
                    video.commentCount = item.statistics.commentCount
                    video.definition = item.contentDetails.definition.uppercased()
                    video.caption = item.contentDetails.caption == "true"
                    video.updatedAt = Date()
                }
            }
        }
    }
}