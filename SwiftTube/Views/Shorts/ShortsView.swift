//
//  ShortsView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 28/09/2025.
//

import SwiftUI
import SwiftData

struct ShortsView: View {
    @Query private var shortVideos: [Video]
    
    @Environment(VideoManager.self) var manager
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
}
