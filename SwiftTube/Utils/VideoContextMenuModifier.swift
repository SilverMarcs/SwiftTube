import SwiftUI

struct VideoContextMenuModifier: ViewModifier {
    let video: Video
    let showChannelLink: Bool
    @Environment(UserDefaultsManager.self) private var userDefaults
    
    func body(content: Content) -> some View {
        content
            .contextMenu {
                Button {
                    userDefaults.toggleWatchLater(video.id)
                } label: {
                    Label(
                        userDefaults.isWatchLater(video.id) ? "Remove from Watch Later" : "Add to Watch Later",
                        systemImage: userDefaults.isWatchLater(video.id) ? "bookmark.fill" : "bookmark"
                    )
                }
                
                if showChannelLink {
                    NavigationLink {
                        ChannelVideoList(channel: video.channel)
                    } label: {
                        Label(video.channel.title, systemImage: "person.circle")
                    }
                }

                Section {
                    ShareLink(item: URL(string: video.url)!) {
                        Label("Share Video", systemImage: "square.and.arrow.up")
                    }
                }
            }
    }
}

extension View {
    func videoContextMenu(video: Video, showChannelLink: Bool = true) -> some View {
        modifier(VideoContextMenuModifier(video: video, showChannelLink: showChannelLink))
    }
}
