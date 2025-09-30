//
//  YTService+Comment.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 28/09/2025.
//

import Foundation

extension YTService {
    static func fetchComments(for video: Video) async throws -> [Comment] {
        let url = URL(string: "\(baseURL)/commentThreads?part=snippet,replies&videoId=\(video.id)&maxResults=100&order=relevance&textFormat=plainText")!
        
        let response: CommentThreadsResponse = try await fetchOAuthResponse(from: url)
        
        var comments: [Comment] = []
        let dateFormatter = YTService.isoFormatter
        
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