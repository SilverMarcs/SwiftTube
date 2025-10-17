import SwiftUI
import AVKit

struct ShortsView: View {
    @Environment(VideoLoader.self) private var videoLoader
    @Environment(VideoManager.self) var videoManager
    
    @State private var shortsPlayer = AVPlayer()
    
    var body: some View {
        NavigationStack {
            TabView {
                ForEach(videoLoader.shortVideos) { video in
                    ShortVideoCard(
                        video: video,
                        player: shortsPlayer
                    )
                }
            }
            .background(.black)
            #if !os(macOS)
            .statusBarHidden(false)
            .tabViewStyle(.page(indexDisplayMode: .never))
            #endif
            .onAppear {
                DispatchQueue.main.async {
                    videoManager.isMiniPlayerVisible = false
                }
                videoManager.player?.pause()
            }
            .onDisappear {
                DispatchQueue.main.async {
                    videoManager.isMiniPlayerVisible = true
                }
                shortsPlayer.pause()
                shortsPlayer.replaceCurrentItem(with: nil)
            }
            .ignoresSafeArea()
        }
    }
}
