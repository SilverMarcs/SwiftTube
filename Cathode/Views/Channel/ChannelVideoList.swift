import SwiftUI

struct ChannelVideoList: View {
    let channelId: String
    let initialTitle: String?

    @Environment(\.openURL) private var openURL
    @Environment(LibraryStore.self) private var library

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
            isGuestAllowed: true,
            onReachEnd: {
                Task { await loadMore() }
            },
            onRefresh: {
                await loadChannelVideos()
            }
        )
        .platformTopBar(displayTitle, titleDisplayMode: .inline) {
            if !channelId.isEmpty {
                subscribeButton
            }
            RefreshButton { await loadChannelVideos() }
        }
        .task {
            if videos.isEmpty {
                await loadChannelVideos()
            }
        }
    }

    @ViewBuilder
    private var subscribeButton: some View {
        // Prefer the resolved channel.id (always UC…) over the raw prop, which
        // can be an @handle when entered from a video card's context menu.
        let resolvedId = channel?.id ?? channelId
        let subscribed = library.isSubscribed(channelId: resolvedId)
        Button {
            let target = channel ?? Channel(id: resolvedId, title: displayTitle)
            library.toggleSubscription(target)
        } label: {
            Label(
                subscribed ? "Subscribed" : "Subscribe",
                systemImage: subscribed ? "bell.fill" : "bell"
            )
            .labelStyle(.iconOnly)
        }
        .help(subscribed ? "Unsubscribe" : "Subscribe")
        #if os(tvOS)
        .tint(.primary)
        #endif
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
