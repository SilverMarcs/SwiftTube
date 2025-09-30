
import SwiftUI
import SwiftMediaViewer

struct ChannelRowView: View {
    let item: ChannelDisplayable
    var subtitle: String?
    
    var body: some View {
        NavigationLink(destination: ChannelDetailView(channelItem: item)) {
            HStack {
                CachedAsyncImage(url:  URL(string: item.thumbnailURL), targetSize: 50)
                    .frame(width: 40, height: 40)
                    .clipShape(.circle)
                
                VStack(alignment: .leading) {
                    Text(item.title)
                        .font(.headline)
                    
                    Text(subtitle ?? item.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
        }
    }
}
