//
//  ContentView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 20/06/2025.
//

import SwiftUI

struct ContentView: View {
    @State private var selection: Tabs = .videos
    @State private var videos: [Video] = []
    @Namespace private var namespace
    
    var body: some View {
        TabView(selection: $selection) {
            Tab("Videos", systemImage: "video", value: .videos) {
                VideosTab(videos: regularVideos)
                    .environment(\.videoNameSpace, namespace)
                    .refreshable {
                        await loadFeed()
                    }
            }
            
            Tab("Shorts", systemImage: "play.rectangle.fill", value: .shorts) {
                ShortsTab(videos: shortsVideos)
            }
            
//            Tab("Subs", systemImage: "person.2", value: .subscriptions) {
//               SubscriptionsTab()
//            }
            
            Tab(value: .search, role: .search) {
                SearchTab()
                    .environment(\.videoNameSpace, namespace)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        #if !os(macOS)
        .tabBarMinimizeBehavior(.onScrollDown)
        #endif
        .task {
            await loadFeed()
        }
    }
    
    private var regularVideos: [Video] {
        videos.filter { !$0.isShort }
    }
    
    private var shortsVideos: [Video] {
        videos.filter { $0.isShort }
    }
    
    private func loadFeed() async {
        let feedVideos = await PipedAPI.shared.fetchSubscribedFeed()
        videos = feedVideos
    }
}

enum Tabs {
    case videos
    case shorts
    case subscriptions
    case search
}
