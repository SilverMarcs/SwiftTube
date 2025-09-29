
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
        HStack {
            CachedAsyncImage(url:  URL(string: item.thumbnailURL), targetSize: 50)
                .frame(width: 40, height: 40)
                .clipShape(.circle)
            
            VStack(alignment: .leading) {
                Text(item.title)
                    .font(.headline)
                
                Text(item.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
    }
}
