
import SwiftUI
import SwiftMediaViewer

struct ChannelRowView: View {
    let item: ChannelDisplayable
    var isNavigation: Bool = true
    
    var body: some View {
        if isNavigation {
            NavigationLink(destination: ChannelDetailView(channelItem: item)) {
                content
            }
        } else {
            content
        }
    }

    var content: some View {
        Label {
            Text(item.title)
            Text(item.subtitle)
        } icon: {
            CachedAsyncImage(url:  URL(string: item.thumbnailURL), targetSize: 50)
                .frame(width: 37, height: 37)
                .clipShape(.circle)
        }
    }
}
