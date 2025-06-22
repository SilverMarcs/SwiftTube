//
//  ShortsTab.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 21/06/2025.
//

import SwiftUI

struct ShortsTab: View {
    let videos: [Video]
    @State private var currentIndex = 0
    
    var body: some View {
        TabView(selection: $currentIndex) {
            ForEach(videos) { video in
                ShortVideoCard(video: video)
                    .tag(video.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
//        .tabViewStyle(PageTabViewStyle())
//        .rotationEffect(.degrees(90))
    }
}
