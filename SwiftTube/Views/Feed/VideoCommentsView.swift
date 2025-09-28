import SwiftUI
import SwiftData

struct VideoCommentsView: View {
    @Environment(VideoManager.self) var manager
    @Environment(\.modelContext) private var modelContext
    
    let video: Video
    
    @State private var isLoading = false
    
    var body: some View {
        LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(video.comments.filter { $0.isTopLevel }.sorted { $0.publishedAt > $1.publishedAt }) { comment in
                CommentRowView(comment: comment)
            }
        }
        .padding(.top, 5)
        .overlay {
            if isLoading {
                UniversalProgressView()
            }
        }
        .task {
            if video.comments.isEmpty {
                await loadComments()
            }
        }
    }
    
    private func loadComments() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let id = video.id
            // Get the managed video object
            let fetchDescriptor = FetchDescriptor<Video>(predicate: #Predicate { $0.id == id })
            guard let managedVideo = try modelContext.fetch(fetchDescriptor).first else {
                return
            }
            
            let fetchedComments = try await YTService.fetchComments(for: managedVideo)
            
            // Clear existing comments for this video
            let existingComments = managedVideo.comments
            for comment in existingComments {
                modelContext.delete(comment)
            }
            
            // Create a dictionary to track top-level comments for reply relationships
            var topLevelComments: [String: Comment] = [:]
            
            // Add new comments
            for comment in fetchedComments {
                comment.video = managedVideo
                modelContext.insert(comment)
                managedVideo.comments.append(comment)
                
                if comment.isTopLevel {
                    topLevelComments[comment.id] = comment
                }
            }
            
            // Set up parent-child relationships for replies
            for comment in fetchedComments {
                if !comment.isTopLevel, let parentId = comment.parentCommentId {
                    if let parentComment = topLevelComments[parentId] {
                        comment.parentComment = parentComment
                        parentComment.replies.append(comment)
                    }
                }
            }
            
            try modelContext.save()
        } catch APIError.commentsDisabled {
            // Comments are disabled for this video
        } catch {
            print(error.localizedDescription)
            // Failed to fetch comments
        }
    }
}
