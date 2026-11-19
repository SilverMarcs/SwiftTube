import SwiftUI
import SwiftMediaViewer

/// The tab bar accessory for the Short on screen. Tapping it opens the Short's details.
struct ShortsAccessoryView: View {
    @Environment(ShortsSession.self) private var session
    @Environment(LibraryStore.self) private var library

    let transitionNamespace: Namespace.ID

    var body: some View {
        if let video = session.feed?.currentVideo {
            let channel = library.channel(for: video)
            let channelName = channel?.title ?? video.channelTitle

            Button {
                session.isShowingDetail = true
            } label: {
                MiniPlayerRow(
                    title: video.title.isEmpty ? "Short" : video.title,
                    subtitle: channelName.isEmpty ? "Channel" : channelName,
                    transitionNamespace: transitionNamespace
                ) {
                    CachedAsyncImage(url: video.channelAvatarURL ?? channel?.thumbnailURL, targetSize: 100) {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .foregroundStyle(.secondary)
                    }
                    .scaledToFill()
                    .frame(width: 34, height: 34)
                    .clipShape(.circle)
                    .accessibilityHidden(true)
                }
            }
            .adaptiveCardButtonStyle()
            .task(id: video.channelId) {
                guard let id = video.channelId, !id.isEmpty,
                      video.channelAvatarURL == nil else { return }
                await library.loadChannel(forId: id)
            }
        }
    }
}
