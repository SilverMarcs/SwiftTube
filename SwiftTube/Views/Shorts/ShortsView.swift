import SwiftUI
import AVKit

struct ShortsView: View {
    @Environment(VideoLoader.self) private var videoLoader
    @Environment(VideoManager.self) var videoManager
    
    @State private var shortsPlayer = AVPlayer()
    @State private var currentVideoId: String?
    
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
                                currentVideoId: $currentVideoId
                            )
                            .containerRelativeFrame([.vertical])
                        }
                    }
                    .scrollTargetLayout()
                }
                .navigationTitle("Shorts")
                .scrollTargetBehavior(.paging)
                .scrollIndicators(.hidden)
#else
                TabView {
                    ForEach(videoLoader.shortVideos) { video in
                        ShortVideoCard(
                            video: video,
                            player: shortsPlayer,
                            currentVideoId: $currentVideoId
                        )
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
            }
            .onDisappear {
                shortsPlayer.pause()
                shortsPlayer.replaceCurrentItem(with: nil)
            }
        }
    }
}
