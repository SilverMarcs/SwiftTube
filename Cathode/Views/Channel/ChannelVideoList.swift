import SwiftUI

struct ChannelVideoList: View {
    let channelId: String
    let initialTitle: String?

    @State private var channel: Channel?
    @State private var videos: [Video] = []
    @State private var nextPageToken: String?
    /// Re-entry guard for `loadMore`.
    @State private var isLoadingMore = false

    init(channelId: String, title: String? = nil) {
        self.channelId = channelId
        self.initialTitle = title
        // Seed from the channel cache so the nav title / avatar render
        // immediately if we already know this channel from the user's subs
        // list (or a previous session).
        _channel = State(initialValue: LibraryStore.shared.channel(forId: channelId))
    }

    private var displayTitle: String {
        channel?.title ?? initialTitle ?? "Channel"
    }

    var body: some View {
        VideoGridView(
            videos: videos,
            showChannelLinkInContextMenu: false,
            onReachEnd: {
                Task { await loadMore() }
            },
            onRefresh: {
                await loadChannelVideos()
            }
        )
        .navigationTitle(displayTitle)
        .platformNavigationToolbar(titleDisplayMode: .inline)
        .task {
            if videos.isEmpty {
                await loadChannelVideos()
            }
        }
    }

    private func loadChannelVideos() async {
        guard !channelId.isEmpty else { return }
        do {
            let (ch, group) = try await InnerTubeAPI.shared.fetchChannel(channelId: channelId)
            self.channel = ch
            LibraryStore.shared.remember(ch)
            self.videos = group.videos
            self.nextPageToken = group.nextPageToken
        } catch {
            print("ChannelVideoList: \(error.localizedDescription)")
        }
    }

    private func loadMore() async {
        guard let token = nextPageToken, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let group = try await InnerTubeAPI.shared.fetchChannelVideos(channelId: channelId, continuationToken: token)
            let existing = Set(videos.map(\.id))
            videos.append(contentsOf: group.videos.filter { !existing.contains($0.id) })
            nextPageToken = group.nextPageToken
        } catch {
            print("ChannelVideoList loadMore: \(error.localizedDescription)")
        }
    }
}
