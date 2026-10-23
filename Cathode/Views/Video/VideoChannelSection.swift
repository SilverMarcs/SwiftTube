import SwiftUI

/// The channel row for a video's detail screen. Owns its own channel-info
/// fetch so the parent doesn't have to thread the result down.
struct VideoChannelSection: View {
    let video: Video

    @Environment(LibraryStore.self) private var library
    /// Backfilled from `/player` when the listing omitted the channel — TV
    /// history and Home tiles often carry only the channel name.
    @State private var resolvedChannelId: String?

    private var channelId: String? {
        if let id = video.channelId, !id.isEmpty { return id }
        return library.channel(for: video)?.id ?? resolvedChannelId
    }

    var body: some View {
        Group {
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
        .task(id: video.id) {
            resolvedChannelId = nil
            if channelId != nil { return }
            do {
                let info = try await InnerTubeAPI.shared.fetchPlayerInfo(videoId: video.id)
                if !Task.isCancelled, let id = info.video.channelId, !id.isEmpty {
                    resolvedChannelId = id
                }
            } catch {
                print("VideoChannelSection channel ID backfill failed: \(error)")
            }
        }
    }
}
