import SwiftUI

/// The channel row for a video's detail screen. Owns its own channel-info
/// fetch so the parent doesn't have to thread the result down.
struct VideoChannelSection: View {
    let video: Video

    @Environment(LibraryStore.self) private var library
    @State private var fetchedChannel: Channel?

    var body: some View {
        if let channelId = video.channelId, !channelId.isEmpty {
            Section {
                ChannelRowView(channel: library.channel(forId: channelId)
                               ?? fetchedChannel
                               ?? Channel(id: channelId, title: video.channelTitle))
                #if os(macOS)
                .padding(8)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 15))
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
                #endif
            }
            #if os(iOS) || os(visionOS)
            .listSectionMargins(.top, 0)
            #endif
            .task(id: channelId) {
                if library.channel(forId: channelId) != nil { return }
                if fetchedChannel?.id == channelId { return }
                do {
                    let channel = try await InnerTubeAPI.shared.fetchChannelInfo(channelId: channelId)
                    if !Task.isCancelled {
                        fetchedChannel = channel
                        library.remember(channel)
                    }
                } catch {
                    print("VideoChannelSection channel fetch failed: \(error)")
                }
            }
        }
    }
}
