import SwiftUI
import SwiftMediaViewer

struct VideoDetailView: View {
    @Environment(UserDefaultsManager.self) private var userDefaults
    @Environment(VideoManager.self) var manager
    
    @State var video: Video    
    
    @State private var isLoading = false
    @State var showDetail: Bool = false
    
    var body: some View {
        NavigationStack {
            List {
                Section(video.title) {
                    // Video Stats (Views, Likes, Published)
                    HStack(spacing: 5) {
                        Label(video.viewCount.formatNumber(), systemImage: "eye")
                            .labelIconToTitleSpacing(3)
                            .font(.system(size: 11))
                        
                        Text("•")
                        Text(video.publishedAt, style: .date)
                        
                        Spacer()
                        
                        if let likesText = video.likeCount?.formatNumber() {
                            Label(likesText, systemImage: "hand.thumbsup.fill")
                                .labelIconToTitleSpacing(3)
                                .font(.system(size: 11))
                        }
                        
                        GlassEffectContainer {
                            ShareLink(item: URL(string: video.url)!) {
                                Label("Share Video", systemImage: "square.and.arrow.up")
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.glass)
                            .controlSize(.mini)
                            
                            Button {
                                userDefaults.toggleWatchLater(video.id)
                            } label: {
                                Label(
                                    userDefaults.isWatchLater(video.id) ? "Remove from Watch Later" : "Add to Watch Later",
                                    systemImage: userDefaults.isWatchLater(video.id) ? "bookmark.fill" : "bookmark"
                                )
                                .labelStyle(.iconOnly)
                            }
                            .foregroundStyle(userDefaults.isWatchLater(video.id) ? .green : .secondary)
                            .buttonStyle(.glass)
                            .controlSize(.mini)
                        }
                    }
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .listRowSeparator(.hidden, edges: .bottom)
                    .listRowInsets([.vertical], 0)
                }
                .headerProminence(.increased)
                .listRowBackground(Color.clear)
                #if !os(macOS)
                .listSectionMargins(.all, 0)
                #endif
                
                // Channel Info
                Section {
                    ChannelRowView(channel: video.channel)
                }
                
                // Description
                if !video.videoDescription.isEmpty {

                Section("Description") {
                    ExpandableText(text: video.videoDescription, maxCharacters: 200)
                        .font(.subheadline)
                    }
                }
                 
                // Comments Section
                Section("Comments") {
                    VideoCommentsView(video: video)
                }
            }
            .overlay {
                if isLoading {
                    UniversalProgressView()
                }
            }
            .formStyle(.grouped)
        }
    }

//    private func loadVideoDetail() async {
//        isLoading = true
//        defer { isLoading = false }
//        
//        do {
//            try await YTService.fetchVideoDetails(for: &video)
//        } catch {
//            print(error.localizedDescription)
//        }
//    }
}
