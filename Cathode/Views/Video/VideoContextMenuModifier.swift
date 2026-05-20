import SwiftUI

struct VideoContextMenuModifier: ViewModifier {
    let video: Video
    let showChannelLink: Bool
    @Environment(LibraryStore.self) private var library

    func body(content: Content) -> some View {
        content
            .contextMenu {
                Button {
                    withAnimation {
                        library.toggleBookmark(video)
                    }
                } label: {
                    Label(
                        library.isBookmarked(video.id) ? "Remove Bookmark" : "Add Bookmark",
                        systemImage: library.isBookmarked(video.id) ? "bookmark.fill" : "bookmark"
                    )
                }

                Button {
                    withAnimation {
                        if let duration = video.duration {
                            library.setResumePosition(videoId: video.id, seconds: duration)
                        }
                    }
                } label: {
                    Label("Mark as Watched", systemImage: "checkmark.circle")
                }

                Section {
                    if showChannelLink, let channelId = video.channelId, !channelId.isEmpty {
                        NavigationLink {
                            ChannelVideoList(channelId: channelId, title: video.channelTitle)
                        } label: {
                            Label(video.channelTitle, systemImage: "person")
                        }
                    }

                    #if !os(tvOS)
                    if let url = video.watchURL {
                        ShareLink(item: url) {
                            Label("Share Video", systemImage: "square.and.arrow.up")
                        }
                    }
                    #endif
                }

                #if os(iOS)
                Section {
                    DownloadMenuButton(video: video)
                        .tint(.primary)
                }
                #endif
            }
    }
}

extension View {
    func videoContextMenu(video: Video, showChannelLink: Bool = true) -> some View {
        modifier(VideoContextMenuModifier(video: video, showChannelLink: showChannelLink))
    }
}
