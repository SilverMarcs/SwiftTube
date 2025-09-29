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
    
    @Environment(VideoManager.self) var manager
    @Environment(\.colorScheme) var colorScheme

    @State private var currentIndex = 0
    
    init() {
        let predicate = #Predicate<Video> { $0.isShort == true }
        let sortDescriptors = [
            SortDescriptor(\Video.watchProgressSeconds, order: .forward),
            SortDescriptor(\Video.publishedAt, order: .reverse)
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
                    ShortVideoCard(video: video, isActive: currentIndex == index)
                        .tag(index)
                }
            }
            .background {
                    CachedAsyncImage(url:  URL(string: shortVideos[currentIndex].thumbnailURL), targetSize: 500)
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
            .ignoresSafeArea()
            .tabViewStyle(.page(indexDisplayMode: .never))
            .task {
                manager.temporarilyStoreCurrentVideo()
            }
            .onDisappear {
                manager.restoreStoredVideo()
            }
        }
    }
}
