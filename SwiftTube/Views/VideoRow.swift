import SwiftUI

struct VideoRow: View {
    let video: Video
    let pipedAPI: PipedAPI
    @State private var isLoadingStreams = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: video.thumbnailURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Rectangle()
                    .fill(.quaternary)
                    .overlay {
                        Image(systemName: "video")
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(width: 120, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Text(video.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack {
                    Text(video.viewsText + " views")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    
                    Text(video.published)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    
                    Spacer()
                    
                    if video.duration > 0 {
                        Text(video.durationText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.black.opacity(0.8))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                
                if isLoadingStreams {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading streams...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
//        .onTapGesture {
//            Task {
//                await fetchVideoStreams()
//            }
//        }
    }
    
//    private func fetchVideoStreams() async {
//        isLoadingStreams = true
//        defer { isLoadingStreams = false }
//
//        do {
//            print("Fetching streams for video: \(video.title) (ID: \(video.id))")
//            let streams = try await pipedAPI.fetchVideoStreams(videoId: video.id)
//
//            print("Successfully fetched streams:")
//            print("- Video streams: \(streams.videoStreams.count)")
//            print("- Audio streams: \(streams.audioStreams.count)")
//            print("- HLS available: \(streams.hlsURL != nil)")
//
//            if let bestVideo = streams.bestVideoStream {
//                print("Best video stream: \(bestVideo.quality) \(bestVideo.format)")
//                print("Video URL: \(bestVideo.url.absoluteString)")
//            }
//
//            if let bestAudio = streams.bestAudioStream {
//                print("Best audio stream: \(bestAudio.format) (\(bestAudio.bitrate ?? 0)kbps)")
//                print("Audio URL: \(bestAudio.url.absoluteString)")
//            }
//
//            if let hlsURL = streams.hlsURL {
//                print("HLS stream URL: \(hlsURL.absoluteString)")
//            }
//
//        } catch {
//            print("Failed to fetch video streams: \(error)")
//        }
//    }
}
