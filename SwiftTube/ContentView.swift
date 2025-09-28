//
//  ContentView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 27/09/2025.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(VideoManager.self) var manager
    @Environment(\.modelContext) private var modelContext
    @Namespace private var animation
    @State var selection: AppTab = .feed
    @State private var videoLoader: VideoLoader?
    
    var body: some View {
        @Bindable var manager = manager
        
        TabView(selection: $selection) {
            Tab("Videos", systemImage: "video", value: .feed) {
                FeedView()
            }
            
            Tab("Shorts", systemImage: "play.rectangle.on.rectangle", value: .shorts) {
                ShortsView()
            }
            
            Tab("Channels", systemImage: "play.rectangle", value: .channels) {
                ChannelListView()
            }

            Tab("Settings", systemImage: "gear", value: .settings, role: .search) {
                SettingsView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        #if os(macOS)
        .tabViewSidebarBottomBar {
            MiniPlayerAccessoryView()
        }
        #else
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            MiniPlayerAccessoryView()
                .matchedTransitionSource(id: "MINIPLAYER", in: animation)
        }
        .fullScreenCover(isPresented: $manager.isExpanded) {
            if let video = manager.currentVideo {
                VideoDetailView(video: video, namespace: animation)
            }
        }
        #endif
        .task {
            // Initialize video loader and load videos on launch
            if videoLoader == nil {
                videoLoader = VideoLoader(modelContainer: modelContext.container)
                await videoLoader?.loadAllChannelVideos()
            }
        }
        .refreshable {
            // Refresh all videos
            await videoLoader?.refreshAllVideos()
        }
    }
}

enum AppTab: String, CaseIterable {
    case feed
    case shorts
    case channels
    case settings
}
