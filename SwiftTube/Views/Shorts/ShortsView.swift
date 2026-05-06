import SwiftUI
import AVKit

struct ShortsView: View {
    @Environment(VideoLoader.self) private var videoLoader
    @Environment(VideoManager.self) var videoManager
    
    @State private var shortsPlayer = AVPlayer()
    @State private var activeVideoId: String?
    /// Exclusive upper bound of the prefetched range in `shortVideos`.
    /// VideoLoader prefetches the first `initialShortsPrefetchCount` on feed load,
    /// and we extend by `prefetchBatchSize` whenever the user nears the edge.
    @State private var prefetchedUpTo: Int = VideoLoader.initialShortsPrefetchCount

    private let prefetchBatchSize = 8
    private let prefetchTriggerLead = 3
    
    var body: some View {
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
        .onChange(of: activeVideoId) { _, newId in
            maybeExtendPrefetch(activeId: newId)
        }
    }

    private func maybeExtendPrefetch(activeId: String?) {
        guard let activeId,
              let index = videoLoader.shortVideos.firstIndex(where: { $0.id == activeId })
        else { return }

        // Trigger when the active index gets within `prefetchTriggerLead` of the prefetched edge.
        guard index + prefetchTriggerLead >= prefetchedUpTo else { return }

        let total = videoLoader.shortVideos.count
        let start = prefetchedUpTo
        let end = min(start + prefetchBatchSize, total)
        guard end > start else { return }

        let batch = videoLoader.shortVideos[start..<end].map(\.id)
        prefetchedUpTo = end
        Task.detached(priority: .utility) {
            await StreamURLCache.shared.prefetch(ids: batch)
        }
    }
}
