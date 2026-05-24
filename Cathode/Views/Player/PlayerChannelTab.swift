import SwiftUI
import SwiftMediaViewer

struct PlayerChannelTab: View {
    let channelId: String
    @State private var videos: [Video] = []
    @State private var isLoading = true
    @State private var hasLoaded = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 35) {
                ForEach(videos) { video in
                    PlayerChannelVideoCard(video: video)
                }
            }
        }
        .scrollClipDisabled()
        .overlay {
            if isLoading {
                UniversalProgressView()
            } else if videos.isEmpty {
                Text("No videos available.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { load() }
    }

    private func load() {
        guard !hasLoaded else { return }
        hasLoaded = true
        guard !channelId.isEmpty else { isLoading = false; return }
        Task {
            do {
                // Mirror ChannelVideoList: the default browse (no Videos-tab params)
                // reliably returns the video grid via parseChannel, while
                // fetchChannelVideos often comes back empty for certain channels.
                let (_, group) = try await InnerTubeAPI.shared.fetchChannel(channelId: channelId)
                videos = group.videos
            } catch {
                print("PlayerChannelTab: \(error.localizedDescription)")
                videos = []
            }
            isLoading = false
        }
    }
}

private struct PlayerChannelVideoCard: View {
    let video: Video

    var body: some View {
        PlayVideoButton(video: video) {
            HStack(spacing: 0) {
                CachedAsyncImage(url: video.thumbnailURL, targetSize: 400)
                    .aspectRatio(16/9, contentMode: .fill)
                    .frame(width: 360, height: 200)
                    .clipped()

                VStack(alignment: .leading, spacing: 6) {
                    Text(video.title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let v = video.viewCount {
                        if let date = video.publishedAt {
                            Text("\(v.formatted(.number.notation(.compactName))) views • \(date.customRelativeFormat())")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("\(v.formatted(.number.notation(.compactName))) views")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if let date = video.publishedAt {
                        Text(date.customRelativeFormat())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(width: 760, height: 200)
        }
    }
}
