import SwiftUI

struct VideoRow: View {
    let video: Video
    let namespace: Namespace.ID
    
    var body: some View {
        NavigationLink(value: video) {
            VStack(alignment: .leading, spacing: 10) {
                AsyncImage(url: video.thumbnailURL) { image in
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fit)
                        .aspectRatio(contentMode: .fit)
                        .overlay(alignment: .bottomTrailing) {
                            if video.duration > 0 {
                                Text(video.durationText)
                                    .font(.caption)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .foregroundStyle(.white)
                                    .background(RoundedRectangle(cornerRadius: 4).fill(.black.secondary))
                                    .padding(10)
                            }
                        }
                } placeholder: {
                    Rectangle()
                        .fill(.background.secondary)
                        .aspectRatio(16/9, contentMode: .fit)
                        .overlay {
                            ProgressView()
                        }
                }
                .matchedTransitionSource(id: "video-\(video.id)", in: namespace)
                .padding(.horizontal, -12)
                .padding(.top, -12)
                // Title
                Text(video.title)
                    .font(.headline)
                    .lineLimit(2)
                
                // Author and view count
                HStack {
                    Text(video.author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()

                    Text("\(video.viewsText) views")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .background(.background.secondary, in: .rect(cornerRadius: 16))
        }
    }
}
