import SwiftUI
import AVFoundation

struct ShortsView: View {
    @Environment(VideoLoader.self) private var videoLoader
    @Environment(VideoManager.self) var videoManager

    @State private var activeVideoId: String?
    @State private var hasLoaded = false

    var body: some View {
        Group {
#if os(macOS)
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(videoLoader.shortVideos) { video in
                        ShortVideoCard(
                            video: video,
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
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(.background)
                    .frame(height: 51)
                    .frame(maxWidth: .infinity)
                    .ignoresSafeArea()
            }
#else
            TabView(selection: $activeVideoId) {
                ForEach(videoLoader.shortVideos) { video in
                    ShortVideoCard(
                        video: video,
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
        .overlay {
            if videoLoader.shortVideos.isEmpty {
                if hasLoaded {
                    ContentUnavailableView("No Shorts", systemImage: "play.rectangle.on.rectangle")
                } else {
                    UniversalProgressView()
                }
            }
        }
        .task {
            videoManager.player?.pause()
            if videoLoader.shortVideos.isEmpty {
                await videoLoader.loadShorts()
            }
            hasLoaded = true
            if activeVideoId == nil {
                activeVideoId = videoLoader.shortVideos.first?.id
            }
        }
        .onChange(of: activeVideoId) { _, newValue in
            guard let newValue,
                  let index = videoLoader.shortVideos.firstIndex(where: { $0.id == newValue })
            else { return }
            // Page the endless feed when the user nears the end of the loaded set.
            if index >= videoLoader.shortVideos.count - 3 {
                Task { await videoLoader.loadMoreShorts() }
            }
        }
    }
}
