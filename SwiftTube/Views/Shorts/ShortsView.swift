import SwiftUI
import AVKit

struct ShortsView: View {
    @Environment(VideoLoader.self) private var videoLoader
    @Environment(VideoManager.self) var videoManager
    
    @State private var shortsPlayer = AVPlayer()
    @State private var activeVideoId: String?
    
    var body: some View {
        NavigationStack {
            Group {
#if os(macOS)
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(videoLoader.shortVideos) { video in
                            ShortVideoCard(
                                video: video,
                                player: shortsPlayer,
                                isActive: video.id == activeVideoId
                            )
                            .id(video.id)
                            .containerRelativeFrame([.vertical])
                        }
                    }
                    .scrollTargetLayout()
                }
                .navigationTitle("Shorts")
                .scrollTargetBehavior(.paging)
                .scrollIndicators(.hidden)
                .scrollPosition(id: $activeVideoId)
#else
                TabView(selection: $activeVideoId) {
                    ForEach(videoLoader.shortVideos) { video in
                        ShortVideoCard(
                            video: video,
                            player: shortsPlayer,
                            isActive: video.id == activeVideoId
                        )
                        .tag(video.id)
                    }
                }
                .background(.black)
                .statusBarHidden(false)
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()
#endif
            }
            .onAppear {
                videoManager.player?.pause()
                // Initialize selection to the first item if not set
                if activeVideoId == nil {
                    activeVideoId = videoLoader.shortVideos.first?.id
                }
            }
            .onDisappear {
                shortsPlayer.pause()
                shortsPlayer.replaceCurrentItem(with: nil)
            }
        }
    }
}
