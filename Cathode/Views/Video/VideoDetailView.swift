import SwiftUI
import SwiftMediaViewer
import AVKit

struct VideoDetailView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(VideoManager.self) var manager
    @Environment(\.colorScheme) var colorScheme

    let video: Video
    @State var showDetail: Bool = false

    var showVideo: Bool = false

    /// Description fetched lazily on appear. The Video objects in lists don't
    /// carry a description (only InnerTube's /player response does), so we
    /// pull it ourselves when not already populated on `video`.
    @State private var fetchedDescription: String?

    private var description: String? {
        let original = video.description?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let original, !original.isEmpty { return original }
        return fetchedDescription
    }

    var body: some View {
        NavigationStack {
            List {
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

                        menu
                    }
                    .font(.system(size: 14))
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

                // Comments Section
                VideoCommentsView(video: video)
            }
            #if os(iOS) || os(visionOS)
            .statusBar(hidden: false)
            .safeAreaBar(edge: .top) {
                if showVideo {
                    AVPlayerViewIos()
                        .background(.bar)
                }
            }
            #endif
            .task(id: video.id) {
                // List videos don't carry shortDescription — only /player does.
                // Fetch lazily on appear when the original is empty.
                let original = video.description?.trimmingCharacters(in: .whitespacesAndNewlines)
                guard original?.isEmpty ?? true else { return }
                do {
                    let info = try await InnerTubeAPI.shared.fetchPlayerInfo(videoId: video.id)
                    if !Task.isCancelled {
                        fetchedDescription = info.video.description
                    }
                } catch {
                    print("VideoDetailView description fetch failed: \(error)")
                }
            }
        }
    }

    var menu: some View {
        Menu {
            #if !os(tvOS)
            if let url = video.watchURL {
                ShareLink(item: url) {
                    Label("Share Video", systemImage: "square.and.arrow.up")
                }
                .tint(.primary)
            }
            #endif

            Button {
                library.toggleBookmark(video)
            } label: {
                Label(
                    library.isBookmarked(video.id) ? "Remove Bookmark" : "Add Bookmark",
                    systemImage: library.isBookmarked(video.id) ? "bookmark.fill" : "bookmark"
                )
            }
            .tint(.primary)

            #if os(iOS)
            Divider()

            DownloadMenuButton(video: video)
                .tint(.primary)
            #endif
        } label: {
            Image(systemName: "ellipsis")
                .padding(10)
        }
        .glassEffect()
    }
}
