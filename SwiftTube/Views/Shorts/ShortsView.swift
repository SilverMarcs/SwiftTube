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

    @State private var currentIndex = 0
    @State private var shuffledVideos: [Video] = []
    
    private var shortVideos: [Video] {
        videoLoader.videos.filter { $0.isShort }
    }
    
    var body: some View {
        NavigationStack {
            TabView(selection: $currentIndex) {
                ForEach(Array(shuffledVideos.enumerated()), id: \.element.id) { index, video in
                    ShortVideoCard(video: video, isActive: currentIndex == index)
                        .tag(index)
                }
            }
            .background {
                if !shuffledVideos.isEmpty {
                    CachedAsyncImage(url: URL(string: shuffledVideos[currentIndex].thumbnailURL), targetSize: 500)
                        .blur(radius: 10)
                        .overlay {
                            Color.black.opacity(0.8)
                        }
                        .clipped()
                        .ignoresSafeArea()
                }
            }
            .ignoresSafeArea()
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: currentIndex) { oldIndex, newIndex in
                if !shuffledVideos.isEmpty && newIndex < shuffledVideos.count {
                    let video = shuffledVideos[newIndex]
                    shortsManager.switchTo(video, at: newIndex)
                }
            }
            .onAppear {
                DispatchQueue.main.async {
                    videoManager.isMiniPlayerVisible = false
                }
                
                shuffledVideos = shortVideos.shuffled()
                
                if !shuffledVideos.isEmpty {
                    let video = shuffledVideos[currentIndex]
                    shortsManager.startPlaying(video, at: currentIndex)
                }
                
                Task {
                    try? await videoManager.player?.pause()
                }
            }
            .onDisappear {
                DispatchQueue.main.async {
                    videoManager.isMiniPlayerVisible = true
                }

                Task {
                    await shortsManager.pause()
                }
            }
            .onChange(of: shortVideos) {
                shuffledVideos = shortVideos.shuffled()
            }
        }
    }
}
