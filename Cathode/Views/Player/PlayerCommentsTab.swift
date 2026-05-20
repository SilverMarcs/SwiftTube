import SwiftUI
import SwiftMediaViewer

struct PlayerCommentsTab: View {
    let video: Video
    @State private var hasLoaded = false
    @State private var topComments: [Comment] = []
    @State private var presentedComment: Comment?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 35) {
                ForEach(topComments) { comment in
                    Button {
                        presentedComment = comment
                    } label: {
                        CommentCardContent(comment: comment)
                    }
                    .buttonStyle(.card)
                }
            }
        }
        .scrollClipDisabled()
        .overlay {
            if !hasLoaded {
                UniversalProgressView()
            }
        }
        .sheet(item: $presentedComment) { comment in
            CommentDetailSheet(comment: comment)
        }
        .task {
            defer { hasLoaded = true }
            do {
                let fetched = try await InnerTubeAPI.shared.fetchComments(videoId: video.id)
                topComments = Array(fetched.prefix(25))
            } catch APIError.commentsDisabled {
                // No comments.
            } catch {
                print("PlayerCommentsTab: \(error.localizedDescription)")
            }
        }
    }
}

private struct CommentCardContent: View {
    let comment: Comment

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                CachedAsyncImage(url: comment.authorAvatarURL, targetSize: 60)
                    .frame(width: 44, height: 44)
                    .clipShape(.circle)

                Text(comment.author)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                Text("•")
                    .foregroundStyle(.secondary)

                Text(comment.publishedTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if !comment.likeCount.isEmpty, comment.likeCount != "0" {
                    Label(comment.likeCount, systemImage: "heart")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(comment.text)
                .font(.subheadline)
                .lineLimit(5)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(width: 480, height: 240, alignment: .top)
    }
}

private struct CommentDetailSheet: View {
    let comment: Comment

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 14) {
                    CachedAsyncImage(url: comment.authorAvatarURL, targetSize: 100)
                        .frame(width: 50, height: 50)
                        .clipShape(.circle)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(comment.author)
                            .font(.headline)
                        Text(comment.publishedTime)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if !comment.likeCount.isEmpty, comment.likeCount != "0" {
                        Label(comment.likeCount, systemImage: "heart")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(comment.text)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(30)
        }
        .frame(width: 900, height: 600)
    }
}
