import SwiftUI

/// The channel row for a video's detail screen.
struct VideoChannelSection: View {
    let video: Video

    @Environment(LibraryStore.self) private var library

    private var channelId: String? {
        if let id = video.channelId, !id.isEmpty { return id }
        return library.channel(for: video)?.id
    }

    var body: some View {
        if let channelId {
            Section {
                ChannelRowView(channel: library.channel(forId: channelId)
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
                await library.loadChannel(forId: channelId)
            }
        }
    }
}
