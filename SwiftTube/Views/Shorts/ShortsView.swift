import SwiftUI
import AVKit

struct ShortsView: View {
    @Environment(VideoLoader.self) private var videoLoader
    @Environment(VideoManager.self) var videoManager
    
    @State private var shortsPlayer = AVPlayer()
    
    var body: some View {
        NavigationStack {
            Group {
#if os(macOS)
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(videoLoader.shortVideos) { video in
                            ShortVideoCard(
                                video: video,
                                player: shortsPlayer
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
                            player: shortsPlayer
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
                #if !os(macOS)
                DispatchQueue.main.async {
                    videoManager.isMiniPlayerVisible = false
                }
                #endif
                videoManager.player?.pause()
            }
            .onDisappear {
                DispatchQueue.main.async {
                    videoManager.isMiniPlayerVisible = true
                }
                shortsPlayer.pause()
                shortsPlayer.replaceCurrentItem(with: nil)
            }
        }
    }
}
