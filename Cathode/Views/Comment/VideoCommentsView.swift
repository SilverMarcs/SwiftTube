import SwiftUI

struct VideoCommentsView: View {
    let video: Video

    @State private var hasLoaded = false
    @State private var comments: [Comment] = []
    @State private var nextPageToken: String?
    @State private var isLoadingMore = false

    var body: some View {
        Section("Comments") {
            if hasLoaded {
                ForEach(comments) { comment in
                    CommentRowView(comment: comment)
                        .onAppear {
                            if comment.id == comments.last?.id { Task { await loadMore() } }
                        }
                }
                if nextPageToken != nil {
                    UniversalProgressView()
                }
            } else {
                UniversalProgressView()
            }
        }
        .task(id: video.id) {
            hasLoaded = false
            comments = []
            nextPageToken = nil
            do {
                let page = try await InnerTubeAPI.shared.fetchComments(videoId: video.id)
                comments = page.comments
                nextPageToken = page.nextPageToken
                hasLoaded = true
            } catch APIError.commentsDisabled {
                hasLoaded = true
            } catch is CancellationError {
                // View was removed before fetch finished — leave state alone.
            } catch let urlError as URLError where urlError.code == .cancelled {
                // URLSession cancellation from SwiftUI tearing down the task.
            } catch {
                print("Error in VideoCommentsView: \(error.localizedDescription)")
                hasLoaded = true
            }
        }
    }

    private func loadMore() async {
        guard let token = nextPageToken, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await InnerTubeAPI.shared.fetchMoreComments(continuationToken: token)
            comments.append(contentsOf: page.comments)
            nextPageToken = page.nextPageToken
        } catch is CancellationError {
        } catch let urlError as URLError where urlError.code == .cancelled {
        } catch {
            print("VideoCommentsView loadMore: \(error.localizedDescription)")
        }
    }
}
