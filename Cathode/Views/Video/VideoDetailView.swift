import SwiftUI
import SwiftMediaViewer
import AVKit

struct VideoDetailView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(VideoManager.self) var manager
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let video: Video
    @State var showDetail: Bool = false

    var showVideo: Bool = false

    @State private var fetchedDescription: String?
    @State private var fetchedChannel: Channel?

    private var description: String? {
        let original = video.description?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let original, !original.isEmpty { return original }
        return fetchedDescription
    }

    var body: some View {
        NavigationStack {
            #if os(macOS)
            compactBody
            #else
            if horizontalSizeClass == .regular {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 0) {
                        if showVideo {
                            AVPlayerViewIos()
                                .background(.black)
                        }

                        VideoDetailsList(
                            video: video,
                            description: description,
                            fetchedChannel: fetchedChannel
                        )
                    }
                    .containerRelativeFrame(.horizontal, count: 3, span: 2, spacing: 16)

                    List {
                        VideoCommentsView(video: video)
                    }
                    .containerRelativeFrame(.horizontal, count: 3, span: 1, spacing: 16)
                }
            } else {
                compactBody
            }
            #endif
        }
        .task(id: video.id) {
            let original = video.description?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard original?.isEmpty ?? true else { return }
            do {
                let info = try await InnerTubeAPI.shared.fetchPlayerInfo(videoId: video.id)
                if !Task.isCancelled {
                    fetchedDescription = info.video.description
                }
            } catch {
                print("VideoDetailView description fetch failed: \(error)")
            }
        }
        .task(id: video.channelId) {
            guard let channelId = video.channelId, !channelId.isEmpty else { return }
            if library.channel(forId: channelId) != nil { return }
            if fetchedChannel?.id == channelId { return }
            do {
                let channel = try await InnerTubeAPI.shared.fetchChannelInfo(channelId: channelId)
                if !Task.isCancelled {
                    fetchedChannel = channel
                    library.remember(channel)
                }
            } catch {
                print("VideoDetailView channel fetch failed: \(error)")
            }
        }
    }

    private var compactBody: some View {
        List {
            VideoDetailsListSection(
                video: video,
                description: description,
                fetchedChannel: fetchedChannel
            )
            VideoCommentsView(video: video)
        }
        #if os(iOS) || os(visionOS)
        .statusBar(hidden: false)
        .safeAreaBar(edge: .top) {
            if showVideo {
                AVPlayerViewIos()
                    .background(.bar)
            }
        }
        #endif
    }
}
