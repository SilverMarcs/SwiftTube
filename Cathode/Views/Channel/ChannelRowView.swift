
import SwiftUI
import SwiftMediaViewer

struct ChannelRowView: View {
    let channel: Channel
    
    var body: some View {
        NavigationLink(destination: ChannelVideoList(channel: channel)) {
            HStack {
                CachedAsyncImage(url:  URL(string: channel.thumbnailURL), targetSize: 50)
                    .frame(width: 40, height: 40)
                    .clipShape(.circle)
                
                VStack(alignment: .leading) {
                    Text(channel.title)
                        .font(.headline)
                    
                    if channel.subscriberCount == 0 {
                        Text(channel.channelDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("\(channel.subscriberCount, format: .number.notation(.compactName)) subscribers")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
        }
    }
}
