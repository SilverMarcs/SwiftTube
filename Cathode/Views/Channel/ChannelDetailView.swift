import SwiftUI
import SwiftMediaViewer

struct ChannelDetailView: View {
    let channel: Channel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    CachedAsyncImage(url: channel.thumbnailURL, targetSize: 400)
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Text(channel.title)
                        .font(.title)
                        .fontWeight(.bold)

                    if let subs = channel.subscriberCount, !subs.isEmpty {
                        Text(subs)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let description = channel.description, !description.isEmpty {
                        Text(LocalizedStringKey(description))
                            .font(.body)
                            .foregroundStyle(.primary)
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Channel Details")
            .platformNavigationToolbar(titleDisplayMode: .inlineLarge)
        }
    }
}
