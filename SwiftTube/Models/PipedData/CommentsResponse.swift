//
//  CommentsResponse.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 21/06/2025.
//

import Foundation

struct CommentsResponse: Codable {
    let comments: [CommentItemResponse]?
    let disabled: Bool?
    let nextpage: String?
}

struct CommentItemResponse: Codable {
    let author: String?
    let commentId: String?
    let commentText: String?
    let commentedTime: String?
    let commentorUrl: String?
    let hearted: Bool?
    let likeCount: Int?
    let pinned: Bool?
    let thumbnail: String?
    let verified: Bool?
    let creatorReplied: Bool?
}
