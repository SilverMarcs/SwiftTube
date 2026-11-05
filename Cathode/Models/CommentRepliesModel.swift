import Foundation
import Observation

@MainActor
@Observable
final class CommentRepliesModel {
    private(set) var replies: [Comment]
    private(set) var nextPageToken: String?
    private(set) var isLoading = false
    private(set) var hasLoaded: Bool
    private(set) var loadFailed = false

    init(comment: Comment) {
        replies = comment.replies
        nextPageToken = comment.replyContinuationToken
        hasLoaded = !comment.replies.isEmpty
    }

    func loadMore() async {
        guard let token = nextPageToken, !isLoading else { return }
        isLoading = true
        loadFailed = false
        defer { isLoading = false }

        do {
            let page = try await InnerTubeAPI.shared.fetchMoreComments(continuationToken: token)
            try Task.checkCancellation()
            var seen = Set(replies.map(\.id))
            replies.append(contentsOf: page.comments.filter { seen.insert($0.id).inserted })
            nextPageToken = page.nextPageToken == token ? nil : page.nextPageToken
            hasLoaded = true
        } catch is CancellationError {
        } catch let error as URLError where error.code == .cancelled {
        } catch {
            loadFailed = true
        }
    }
}
