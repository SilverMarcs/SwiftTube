//
//  ShortsView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 28/09/2025.
//

import SwiftUI
import SwiftMediaViewer

struct ShortsView: View {
    @Environment(VideoLoader.self) private var videoLoader
    @Environment(VideoManager.self) var videoManager
    @Environment(ShortsManager.self) var shortsManager
    @Environment(UserDefaultsManager.self) var userDefaults

    @State private var currentIndex = 0
    @State private var isReady = false

    var body: some View {
        NavigationStack {
            if isReady {
                TabView(selection: $currentIndex) {
                    ForEach(Array(videoLoader.shortVideos.enumerated()), id: \.element.id) { index, video in
                        ShortVideoCard(video: video, isActive: currentIndex == index)
                            .tag(index)
                    }
                }
                .background {
                    if !videoLoader.shortVideos.isEmpty {
                        CachedAsyncImage(url: URL(string: videoLoader.shortVideos[currentIndex].thumbnailURL), targetSize: 500)
                            .blur(radius: 10)
                            .overlay {
                                Color.black.opacity(0.8)
                            }
                            .clipped()
                            .ignoresSafeArea()
                    }
                }
                #if !os(macOS)
                .tabViewStyle(.page(indexDisplayMode: .never))
                #endif
                .onChange(of: currentIndex) {
                    if !videoLoader.shortVideos.isEmpty && currentIndex <  videoLoader.shortVideos.count {
                        let video =  videoLoader.shortVideos[currentIndex]
                        shortsManager.switchTo(video, at: currentIndex)
                    }
                }
                .onAppear {
                    DispatchQueue.main.async {
                        videoManager.isMiniPlayerVisible = false
                    }

                    Task {
                        try? await videoManager.player?.pause()
                    }
                    
                    if !videoLoader.shortVideos.isEmpty {
                        let video =  videoLoader.shortVideos[currentIndex]
                        shortsManager.startPlaying(video, at: currentIndex)
                    }
                }
                .ignoresSafeArea()
            } else {
                ProgressView()
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 1_000_000)
            isReady = true
        }
        .onDisappear {
            isReady = false
            
            DispatchQueue.main.async {
                videoManager.isMiniPlayerVisible = true
            }
            
            Task {
                await shortsManager.pause()
            }
        }
    }
}
