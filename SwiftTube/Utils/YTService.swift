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
        let url = URL(string: "\(baseURL)/channels?part=snippet,contentDetails,statistics&forHandle=\(encoded)&key=\(apiKey)")!
        
        let response: ChannelResponse = try await fetchResponse(from: url)
        
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
        guard let apiKey = apiKey else {
            throw APIError.invalidAPIKey
        }
        
        let url = URL(string: "\(baseURL)/channels?part=snippet,contentDetails,statistics&id=\(channelId)&key=\(apiKey)")!
        
        let response: ChannelResponse = try await fetchResponse(from: url)
        
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
    
    static func fetchVideoDetails(for video: Video) async throws {
        guard let apiKey = apiKey else {
            throw APIError.invalidAPIKey
        }
        
        let url = URL(string: "\(baseURL)/videos?part=snippet,contentDetails,statistics&id=\(video.id)&key=\(apiKey)")!
        
        let response: VideoDetailResponse = try await fetchResponse(from: url)
        
        guard let item = response.items.first else {
            throw APIError.videoNotFound
        }
        
        let duration = parseDurationToSeconds(item.contentDetails.duration)
        video.duration = duration
        video.isShort = duration <= 120 // Videos 60 seconds or less are considered shorts
        video.viewCount = item.statistics.viewCount
        video.likeCount = item.statistics.likeCount
        video.commentCount = item.statistics.commentCount
        video.definition = item.contentDetails.definition.uppercased()
        video.caption = item.contentDetails.caption == "true"
        video.updatedAt = Date()
    }
    
    static func fetchVideoDetails(for videos: [Video]) async throws {
        guard let apiKey = apiKey else {
            throw APIError.invalidAPIKey
        }
        
        // Split into chunks of 50 (YouTube API limit)
        let chunks = videos.chunked(into: 50)
        
        for chunk in chunks {
            let videoIds = chunk.map { $0.id }.joined(separator: ",")
            let url = URL(string: "\(baseURL)/videos?part=snippet,contentDetails,statistics&id=\(videoIds)&key=\(apiKey)")!
            
            let response: VideoDetailResponse = try await fetchResponse(from: url)
            
            // Update each video with the fetched details
            for item in response.items {
                if let video = chunk.first(where: { $0.id == item.id }) {
                    let duration = parseDurationToSeconds(item.contentDetails.duration)
                    video.duration = duration
                    video.isShort = duration <= 120 // Videos 60 seconds or less are considered shorts
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
    
    static func fetchComments(for video: Video) async throws -> [Comment] {
        guard let apiKey = apiKey else {
            throw APIError.invalidAPIKey
        }
        
        let url = URL(string: "\(baseURL)/commentThreads?part=snippet,replies&videoId=\(video.id)&maxResults=100&order=relevance&textFormat=plainText&key=\(apiKey)")!
        
        let response: CommentThreadsResponse = try await fetchResponse(from: url)
        
        var comments: [Comment] = []
        let dateFormatter = ISO8601DateFormatter()
        
        for thread in response.items {
            // Create top-level comment
            let topComment = thread.snippet.topLevelComment
            let publishedAt = dateFormatter.date(from: topComment.snippet.publishedAt) ?? Date()
            let updatedAt = topComment.snippet.updatedAt.flatMap { dateFormatter.date(from: $0) }
            
            let comment = Comment(
                id: topComment.id,
                authorDisplayName: topComment.snippet.authorDisplayName,
                authorProfileImageUrl: topComment.snippet.authorProfileImageUrl,
                textDisplay: topComment.snippet.textDisplay,
                textOriginal: topComment.snippet.textOriginal,
                likeCount: topComment.snippet.likeCount,
                publishedAt: publishedAt,
                updatedAt: updatedAt,
                totalReplyCount: thread.snippet.totalReplyCount,
                isTopLevel: true,
                parentCommentId: nil
                // video: video  // Don't set here, set in loadComments with managed video
            )
            
            comments.append(comment)
            
            // Add replies if available
            if let replies = thread.replies?.comments {
                for reply in replies {
                    let replyPublishedAt = dateFormatter.date(from: reply.snippet.publishedAt) ?? Date()
                    let replyUpdatedAt = reply.snippet.updatedAt.flatMap { dateFormatter.date(from: $0) }
                    
                    let replyComment = Comment(
                        id: reply.id,
                        authorDisplayName: reply.snippet.authorDisplayName,
                        authorProfileImageUrl: reply.snippet.authorProfileImageUrl,
                        textDisplay: reply.snippet.textDisplay,
                        textOriginal: reply.snippet.textOriginal,
                        likeCount: reply.snippet.likeCount,
                        publishedAt: replyPublishedAt,
                        updatedAt: replyUpdatedAt,
                        totalReplyCount: 0,
                        isTopLevel: false,
                        parentCommentId: topComment.id
                        // video: video
                    )
                    
                    comments.append(replyComment)
                }
            }
        }
        
        return comments
    }
}
