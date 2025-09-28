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
    
    @State private var currentIndex = 0
    
    var body: some View {
        NavigationStack {
            if shortVideos.isEmpty {
                ContentUnavailableView(
                    "No Shorts Available",
                    systemImage: "play.rectangle.on.rectangle",
                    description: Text("Shorts will appear here once video details are loaded")
                )
            } else {
                TabView(selection: $currentIndex) {
                    ForEach(Array(shortVideos.enumerated()), id: \.element.id) { index, video in
                        ShortVideoCard(video: video)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
//                .ignoresSafeArea()
            }
        }
        .navigationTitle("Shorts")
        .toolbarTitleDisplayMode(.inline)
    }
}
