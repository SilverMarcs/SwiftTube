
import SwiftUI
import SwiftMediaViewer

struct ChannelRowView: View {
    let channel: Channel
    
    var body: some View {
        HStack {
            CachedAsyncImage(url:  URL(string: channel.thumbnailURL), targetSize: 50)
                .frame(width: 40, height: 40)
                .clipShape(.circle)
            
            VStack(alignment: .leading) {
                Text(channel.title)
                    .font(.headline)
                
                Text("\(Int(channel.subscriberCount).formatNumber()) subscribers")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
}
