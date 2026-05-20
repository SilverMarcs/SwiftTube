import SwiftUI
import SwiftMediaViewer

extension Comment {
    /// Compacts YouTube's relative time strings ("8 hours ago (edited)") into
    /// the short form ("8h"). Drops the "(edited)" tag.
    var shortPublishedTime: String {
        let stripped = publishedTime
            .replacingOccurrences(of: "(edited)", with: "")
            .trimmingCharacters(in: .whitespaces)
        // Match "<N> <unit>s? ago"
        let pattern = #"^(\d+)\s+(second|minute|hour|day|week|month|year)s?\s+ago$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: stripped, range: NSRange(stripped.startIndex..., in: stripped)),
              let nRange = Range(match.range(at: 1), in: stripped),
              let uRange = Range(match.range(at: 2), in: stripped)
        else {
            return stripped
        }
        let n = stripped[nRange]
        switch stripped[uRange].lowercased() {
        case "second": return "\(n)s"
        case "minute": return "\(n)m"
        case "hour":   return "\(n)h"
        case "day":    return "\(n)d"
        case "week":   return "\(n)w"
        case "month":  return "\(n)mo"
        case "year":   return "\(n)y"
        default:       return stripped
        }
    }
}

struct CommentRowView: View {
    let comment: Comment

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                CachedAsyncImage(url: comment.authorAvatarURL, targetSize: 50)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 25, height: 25)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(comment.author)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text(comment.shortPublishedTime)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()
                    }

                    Text(comment.text)
                        .font(.callout)
                        .opacity(0.85)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        if !comment.likeCount.isEmpty, comment.likeCount != "0" {
                            HStack(spacing: 4) {
                                Image(systemName: "heart")
                                Text(comment.likeCount)
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                        // TODO: reply expansion — InnerTube returns flat top-level
                        // comments only. Wire up a reply continuation fetch later.
                        Spacer()
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
