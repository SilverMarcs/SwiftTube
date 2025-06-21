//
//  VideoCommentsView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 21/06/2025.
//

import SwiftUI

struct VideoCommentsView: View {
    let videoId: String
    
    @State private var commentsData: CommentsData?
    @State private var isLoading = true
    
    var body: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            if isLoading {
                ProgressView("Loading comments...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let commentsData = commentsData {
                if commentsData.isDisabled {
                    Text("Comments are disabled for this video")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if commentsData.comments.isEmpty {
                    Text("No comments found")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    commentsListView
                }
            } else {
                Text("Failed to load comments")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await fetchComments()
        }
    }
    
    private var commentsListView: some View {
        ForEach(commentsData?.comments ?? []) { comment in
            CommentRowView(comment: comment)
        }
    }
    
    private func fetchComments() async {
        isLoading = true
        commentsData = await PipedAPI.shared.fetchComments(videoId: videoId)
        isLoading = false
    }
}

struct CommentRowView: View {
    let comment: Comment
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: URL(string: comment.thumbnailUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(.gray.opacity(0.3))
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(comment.author)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if comment.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.blue)
                            .font(.caption)
                    }
                    
                    Text(comment.timeAgo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    if comment.isPinned {
                        Image(systemName: "pin.fill")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
                
                Text(comment.text)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: comment.isHearted ? "heart.fill" : "hand.thumbsup")
                            .foregroundStyle(comment.isHearted ? .red : .secondary)
                            .font(.caption)
                        
                        if comment.likeCount > 0 {
                            Text("\(comment.likeCount)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if comment.creatorReplied {
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.left")
                                .foregroundStyle(.blue)
                                .font(.caption)
                            
                            Text("Creator replied")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
    }
}

#Preview {
    VideoCommentsView(videoId: "dQw4w9WgXcQ")
}
