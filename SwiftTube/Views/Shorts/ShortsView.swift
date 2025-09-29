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
    @State private var randomizedVideos: [Video] = []
    
    init() {
        let predicate = #Predicate<Video> { $0.isShort == true }
        // Remove sort descriptors since we'll randomize manually
        _shortVideos = Query(filter: predicate)
    }
    
    var body: some View {
        NavigationStack {
            TabView(selection: $currentIndex) {
                ForEach(Array(randomizedVideos.enumerated()), id: \.element.id) { index, video in
                    ShortVideoCard(video: video, isActive: currentIndex == index)
                        .tag(index)
                }
            }
            .background {
                if !randomizedVideos.isEmpty {
                    CachedAsyncImage(url: URL(string: randomizedVideos[currentIndex].thumbnailURL), targetSize: 500)
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
            .onAppear {
                randomizeVideos()
            }
//            .onChange(of: shortVideos) { _, _ in
//                randomizeVideos()
//            }
        }
    }
    
    private func randomizeVideos() {
        randomizedVideos = shortVideos.shuffled()
        currentIndex = 0
    }
}
