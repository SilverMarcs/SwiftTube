//
//  ShortsView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 28/09/2025.
//

import SwiftUI
import SwiftMediaViewer
import AVKit

struct ShortsView: View {
    @Environment(VideoLoader.self) private var videoLoader
    @Environment(NativeVideoManager.self) var videoManager

    @State private var currentIndex = 0

    var body: some View {
        NavigationStack {
            TabView(selection: $currentIndex) {
                ForEach(Array(videoLoader.shortVideos.enumerated()), id: \.element.id) { index, video in
                    ShortVideoCard(video: video, isActive: currentIndex == index)
                        .tag(index)
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
            }
            .ignoresSafeArea()
        }
    }
}
