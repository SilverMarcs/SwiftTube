#if !os(tvOS)
import SwiftUI
import SwiftMediaViewer

struct MiniPlayerAccessoryView: View {
    @Environment(VideoManager.self) var manager

    var transitionNamespace: Namespace.ID?

    var body: some View {
        if let video = manager.currentVideo {
            MiniPlayerRow(
                title: video.title,
                subtitle: video.channelTitle,
                isPlaying: manager.isPlaying,
                isLoading: manager.isSetting,
                transitionNamespace: transitionNamespace,
                togglePlayback: manager.togglePlayPause
            ) {
                CachedAsyncImage(url: video.thumbnailURL, targetSize: 500)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 34)
                    .clipShape(.rect(cornerRadius: 10))
            }
        }
    }
}
#endif
