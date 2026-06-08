import SwiftUI

struct VideoDetailsListSection: View {
    let video: Video
    let description: String?
    let fetchedChannel: Channel?

    @Environment(LibraryStore.self) private var library

    var body: some View {
        Group {
            #if os(iOS) || os(visionOS)
            Section(video.title) {
                HStack(spacing: 5) {
                    if let viewCount = video.viewCount {
                        Text("\(viewCount, format: .number.notation(.compactName)) views")
                    }

                    if video.viewCount != nil, video.publishedAt != nil {
                        Text("•")
                    }

                    if let date = video.publishedAt {
                        Text(date, style: .date)
                    }

                    Spacer()

                    VideoDetailMenuView(video: video)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .listRowSeparator(.hidden, edges: .bottom)
                .listRowInsets([.vertical], 0)
            }
            .headerProminence(.increased)
            .listRowBackground(Color.clear)
            .listSectionMargins(.all, 0)
            #endif

            // Channel info — only when we know the channel id.
            if let channelId = video.channelId, !channelId.isEmpty {
                Section {
                    ChannelRowView(channel: library.channel(forId: channelId)
                                   ?? fetchedChannel
                                   ?? Channel(id: channelId, title: video.channelTitle))
                    #if os(macOS)
                    .padding(8)
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 15))
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                    #endif
                }
                #if os(iOS) || os(visionOS)
                .listSectionMargins(.top, 0)
                #endif
            }

            // Description
            if let description, !description.isEmpty {
                Section("Description") {
                    ExpandableText(text: description, maxCharacters: 200)
                        .font(.subheadline)
                        #if os(macOS)
                        .listRowSeparator(.hidden, edges: .bottom)
                        #endif
                }
            }
        }
    }
}
