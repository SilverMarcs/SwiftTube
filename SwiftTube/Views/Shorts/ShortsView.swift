//
//  ShortsView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 28/09/2025.
//

import SwiftUI
import SwiftData

struct ShortsView: View {
    @Query(
        filter: #Predicate<Video> { $0.isShort == true },
        sort: \Video.publishedAt,
        order: .reverse
    ) private var shortVideos: [Video]
    
    @Environment(VideoManager.self) var manager
    @State private var currentIndex = 0
    
    var body: some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(shortVideos.enumerated()), id: \.element.id) { index, video in
                ShortVideoCard(video: video, isActive: currentIndex == index)
                    .tag(index)
            }
        }
        .background(.black)
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
