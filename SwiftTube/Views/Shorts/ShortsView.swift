//
//  ShortsView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 28/09/2025.
//

import SwiftUI
import SwiftMediaViewer
import SwiftData

struct ShortsView: View {
    @Query private var shortVideos: [Video]
    
    @Environment(VideoManager.self) var videoManager
    @Environment(ShortsManager.self) var shortsManager
    @Environment(\.colorScheme) var colorScheme

    @State private var currentIndex = 0
    
    init() {
        let predicate = #Predicate<Video> { $0.isShort == true }
        let sortDescriptors = [
            SortDescriptor(\Video.lastWatchedAt, order: .forward), // nil values first (unwatched), then by date
            SortDescriptor(\Video.publishedAt, order: .reverse) // newer videos first within each group
        ]
        
        _shortVideos = Query(
            filter: predicate,
            sort: sortDescriptors
        )
    }
    
    var body: some View {
        NavigationStack {
            TabView(selection: $currentIndex) {
                ForEach(Array(shortVideos.enumerated()), id: \.element.id) { index, video in
                    ShortVideoCard(video: video, isActive: currentIndex == index, shortsManager: shortsManager)
                        .tag(index)
                }
            }
            .background {
                if !shortVideos.isEmpty {
                    CachedAsyncImage(url: URL(string: shortVideos[currentIndex].thumbnailURL), targetSize: 500)
                        .blur(radius: 10)
                        .overlay {
                            if colorScheme == .dark {
                                Color.black.opacity(0.8)
                            } else {
                                Color.white.opacity(0.5)
                            }
                        }
                        .clipped()
                        .ignoresSafeArea()
                }
            }
            .ignoresSafeArea()
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: currentIndex) { oldIndex, newIndex in
                if !shortVideos.isEmpty && newIndex < shortVideos.count {
                    let video = shortVideos[newIndex]
                    shortsManager.switchTo(video, at: newIndex)
                }
            }
            .onAppear {
                if !shortVideos.isEmpty {
                    let video = shortVideos[currentIndex]
                    shortsManager.startPlaying(video, at: currentIndex)
                }
            }
            .onDisappear {
                shortsManager.markCurrentVideoAsWatchedIfNeeded()
                Task {
                    await shortsManager.pause()
                }
            }
        }
        .environment(shortsManager)
    }
}
