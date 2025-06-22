//
//  VideosTab.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 23/06/2025.
//

import SwiftUI

struct VideosTab: View {
    let videos: [Video]
    @State private var showSettings = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(videos) { video in
                    VideoRow(video: video)
                        .listRowInsets(.vertical, 7)
                        .listRowInsets(.horizontal, 10)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .settingsToolbar(showSettings: $showSettings)
            .navigationDestinations()
            .navigationTitle("Videos")
            .toolbarTitleDisplayMode(.inlineLarge)
        }
        .navigationLinkIndicatorVisibility(.hidden)
    }
}
