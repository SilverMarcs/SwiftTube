//
//  ContentView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 27/09/2025.
//

import SwiftUI
import YouTubePlayerKit

struct ContentView: View {
    @Environment(VideoManager.self) var manager
    @Namespace private var animation    
    @State var selection: AppTab = .feed
    
    var body: some View {
        @Bindable var manager = manager
        
        TabView(selection: $selection) {
            Tab("Videos", systemImage: "tv", value: .feed) {
                FeedView()
            }
            
            Tab("Channels", systemImage: "list.bullet", value: .channels) {
                ChannelListView()
            }

            Tab("Settings", systemImage: "gear", value: .settings) {
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
                VideoDetailView(video: video)
                    .safeAreaInset(edge: .top, spacing: 0) {
                        if let player = manager.youTubePlayer {
                            YouTubePlayerView(player)
                                .aspectRatio(16/9, contentMode: .fit)
                                .navigationTransition(.zoom(sourceID: "MINIPLAYER", in: animation))
                        }
                    }
            }
        }
        #endif
    }
}

enum AppTab: String, CaseIterable {
    case feed
    case channels
    case settings
}
