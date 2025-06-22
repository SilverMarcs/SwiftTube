import SwiftUI
import Kingfisher

struct VideoRow: View {
    @Environment(\.videoNameSpace) private var namespace
    let video: Video
    
    var body: some View {
        NavigationLink(value: video) {
            VStack(alignment: .leading, spacing: 10) {
                KFImage(video.thumbnailURL)
                    .placeholder {
                        Rectangle()
                            .fill(.background.secondary)
                            .aspectRatio(16/9, contentMode: .fit) // Match the final image's aspect ratio
                            .frame(maxWidth: .infinity, maxHeight: 400) // Match the final image's max height
                            .overlay(
                                ProgressView()
                            )
                    }
                    .downsampling(size: CGSize(width: 640, height: 360))
                    .serialize(as: .JPEG)
                    .fade(duration: 0.2)
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fit)
                    .frame(maxHeight: 400)
                    .overlay(alignment: .bottomTrailing) {
                        Text(video.durationText)
                            .font(.caption)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .foregroundStyle(.white)
                            .background(RoundedRectangle(cornerRadius: 4).fill(.black.secondary))
                            .padding(10)
                    }
                    .padding(.horizontal, -12)
                    .padding(.top, -12)
                
                Text(video.title)
                    .font(.headline)
                    .lineLimit(2)
                
                HStack {
                    if let uploaderUrl = video.uploaderAvatar, let url = URL(string: uploaderUrl) {
                        KFImage(url)
                            .downsampling(size: CGSize(width: 44, height: 44))
                            .serialize(as: .JPEG)
                            .fade(duration: 0.2)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 22, height: 22)
                            .clipShape(Circle())
                    }
                    
                    Text(video.uploaderName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()

                    Text(video.viewsText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .background(.background.secondary, in: .rect(cornerRadius: 16))
            .matchedTransitionSource(id: "video-\(video.id)", in: namespace ?? Namespace().wrappedValue)
        }
    }
}
