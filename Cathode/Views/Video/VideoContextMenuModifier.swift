import SwiftUI

struct VideoContextMenuModifier: ViewModifier {
    let video: Video
    let showChannelLink: Bool
    @Environment(CloudStoreManager.self) private var userDefaults
    
    func body(content: Content) -> some View {
        content
            .contextMenu {
                Button {
                    withAnimation {
                        userDefaults.toggleBookmark(video)
                    }
                } label: {
                    Label(
                        userDefaults.isBookmarked(video.id) ? "Remove Bookmark" : "Add Bookmark",
                        systemImage: userDefaults.isBookmarked(video.id) ? "bookmark.fill" : "bookmark"
                    )
                }
                
                Button {
                    withAnimation {
                        video.updateWatchProgress(Double(video.duration ?? 0))
                    }
                } label: {
                    Label("Mark as Watched", systemImage: "checkmark.circle")
                }

                Section {
                    if showChannelLink {
                        NavigationLink {
                            ChannelVideoList(channel: video.channel)
                        } label: {
                            Label(video.channel.title, systemImage: "person")
                        }
                    }
                    
                    #if !os(tvOS)
                    ShareLink(item: URL(string: video.url)!) {
                        Label("Share Video", systemImage: "square.and.arrow.up")
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
