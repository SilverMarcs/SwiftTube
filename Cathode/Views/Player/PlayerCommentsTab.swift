import SwiftUI
import SwiftMediaViewer

struct PlayerCommentsTab: View {
    let video: Video
    @State private var hasLoaded = false
    @State private var comments: [Comment] = []

    private var topLevelComments: [Comment] {
        comments.filter { $0.isTopLevel }.sorted { $0.publishedAt > $1.publishedAt }
    }

    var body: some View {
        Group {
            if !hasLoaded {
                UniversalProgressView()
            } else if topLevelComments.isEmpty {
                ContentUnavailableView("No comments", systemImage: "bubble.left.and.bubble.right")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 24) {
                        ForEach(topLevelComments) { comment in
                            CommentCard(comment: comment)
                        }
                    }
                    .padding(24)
                }
            }
        }
        .task {
            defer { hasLoaded = true }
            do {
                comments = try await YTService.fetchComments(for: video)
            } catch APIError.commentsDisabled {
                // Comments disabled — ContentUnavailableView covers this.
            } catch {
                print("PlayerCommentsTab: \(error.localizedDescription)")
            }
        }
    }
}

private struct CommentCard: View {
    let comment: Comment

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                CachedAsyncImage(url: URL(string: comment.authorProfileImageUrl ?? ""), targetSize: 50)
                    .frame(width: 36, height: 36)
                    .clipShape(.circle)
                VStack(alignment: .leading, spacing: 2) {
                    Text(comment.authorDisplayName)
                        .font(.subheadline.weight(.medium))
                    Text(comment.publishedAt.customRelativeFormat())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Text(comment.textOriginal)
                .font(.callout)
                .lineLimit(8)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            if comment.likeCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "heart")
                    Text("\(comment.likeCount)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 440, height: 300, alignment: .top)
        .background(.background.secondary, in: .rect(cornerRadius: 16))
    }
}
