//
//  Comment.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 21/06/2025.
//

import Foundation

struct Comment: Identifiable, Codable {
    let id: String
    let author: String
    let text: String
    let timeAgo: String
    let authorUrl: String
    let thumbnailUrl: String
    let likeCount: Int
    let isHearted: Bool
    let isPinned: Bool
    let isVerified: Bool
    let creatorReplied: Bool
}

struct CommentsData: Codable {
    let comments: [Comment]
    let isDisabled: Bool
    let nextPage: String?
}

extension CommentItemResponse {
    func toComment() -> Comment? {
        guard let id = commentId,
              let author = author,
              let text = commentText,
              let timeAgo = commentedTime,
              let authorUrl = commentorUrl,
              let thumbnailUrl = thumbnail else {
            return nil
        }
        
        return Comment(
            id: id,
            author: author,
            text: text,
            timeAgo: timeAgo,
            authorUrl: authorUrl,
            thumbnailUrl: thumbnailUrl,
            likeCount: likeCount ?? 0,
            isHearted: hearted ?? false,
            isPinned: pinned ?? false,
            isVerified: verified ?? false,
            creatorReplied: creatorReplied ?? false
        )
    }
}

extension CommentsResponse {
    func toCommentsData() -> CommentsData {
        let comments = self.comments?.compactMap { $0.toComment() } ?? []
        return CommentsData(
            comments: comments,
            isDisabled: disabled ?? false,
            nextPage: nextpage
        )
    }
}
