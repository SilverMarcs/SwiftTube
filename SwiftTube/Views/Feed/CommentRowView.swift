import SwiftUI

struct CommentRowView: View {
    let comment: Comment
    @State private var showReplies = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                // Author Profile Image
                AsyncImage(url: URL(string: comment.authorProfileImageUrl ?? "")) { image in
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
                    // Author name and timestamp
                    HStack {
                        Text(comment.authorDisplayName)
                            .font(.caption.weight(.medium))
                        
                        Text(comment.publishedAt, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                    }
                    
                    // Comment text
                    Text(comment.textOriginal)
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Like count and reply button
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
                                showReplies.toggle()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: showReplies ? "chevron.up" : "chevron.down")
                                    Text("\(comment.totalReplyCount) replies")
                                }
                                .font(.caption2)
                                .foregroundStyle(.blue)
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