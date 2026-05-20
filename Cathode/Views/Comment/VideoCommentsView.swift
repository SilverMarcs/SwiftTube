import SwiftUI

struct VideoCommentsView: View {
    let video: Video

    @State private var hasLoaded = false
    @State private var comments: [Comment] = []

    var body: some View {
        if hasLoaded {
            Section("Comments") {
                ForEach(comments) { comment in
                    CommentRowView(comment: comment)
                }
            }
        } else {
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
        defer { hasLoaded = true }
        do {
            comments = try await InnerTubeAPI.shared.fetchComments(videoId: video.id)
        } catch APIError.commentsDisabled {
            // Comments are disabled for this video.
        } catch {
            print("Error in VideoCommentsView: \(error.localizedDescription)")
        }
    }
}
