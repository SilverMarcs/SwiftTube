import SwiftUI
import SwiftMediaViewer

struct CommentRowView: View {
    let comment: Comment
    @State private var showReplies = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                CachedAsyncImage(url: URL(string: comment.authorProfileImageUrl ?? ""), targetSize: 50)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 25, height: 25)
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(comment.authorDisplayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(comment.publishedAt.customRelativeFormat())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                                             
                        Spacer()
                    }
                    
                    Text(comment.textOriginal)
                        .font(.callout)
                         .opacity(0.85)
                         .fixedSize(horizontal: false, vertical: true)
                    
                    HStack {
                        if comment.likeCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "hand.thumbsup")
                                Text("\(comment.likeCount)")
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                        
                        if comment.totalReplyCount > 0 {
                            Button {
                                withAnimation {
                                    showReplies.toggle()
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: showReplies ? "chevron.up" : "chevron.down")
                                    Text("\(comment.totalReplyCount) replies")
                                }
                                .font(.caption2)
                                .foregroundStyle(.accent)
                            }
                        }
                        
                        Spacer()
                    }
                }
            }
            
            // Replies
            if showReplies && comment.totalReplyCount > 0 {
                let replies = comment.replies.sorted { $0.publishedAt < $1.publishedAt }
                ForEach(replies) { reply in
                    HStack {
                        Spacer()
                            .frame(width: 20)
                        CommentRowView(comment: reply)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
