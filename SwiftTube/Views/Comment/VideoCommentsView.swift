import SwiftUI

struct VideoCommentsView: View {
    @Environment(NativeVideoManager.self) var manager
    
    let video: Video
    
    @State private var isLoading = false
    @State private var comments: [Comment] = []
    
    private var topLevelComments: [Comment] {
        comments.filter { $0.isTopLevel }.sorted { $0.publishedAt > $1.publishedAt }
    }
    
    var body: some View {
        ForEach(topLevelComments) { comment in
            CommentRowView(comment: comment)
        }
        
        if comments.isEmpty {
            Color.clear.frame(height: 1)
                .overlay {
                    UniversalProgressView()
                }
                .task {
                    await loadComments()
                }
        }
    }
    
    private func loadComments() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            var fetchedComments = try await YTService.fetchComments(for: video)
            
            // Create a dictionary to track top-level comments for reply relationships
            var topLevelCommentsDict: [String: Int] = [:]
            
            // Find indices of top-level comments
            for (index, comment) in fetchedComments.enumerated() {
                if comment.isTopLevel {
                    topLevelCommentsDict[comment.id] = index
                }
            }
            
            // Set up parent-child relationships for replies
            for i in 0..<fetchedComments.count {
                if !fetchedComments[i].isTopLevel, let parentId = fetchedComments[i].parentCommentId {
                    if let parentIndex = topLevelCommentsDict[parentId] {
                        fetchedComments[parentIndex].replies.append(fetchedComments[i])
                    }
                }
            }
            
            comments = fetchedComments
        } catch APIError.commentsDisabled {
            // Comments are disabled for this video
        } catch {
            print(error.localizedDescription)
            // Failed to fetch comments
        }
    }
}
