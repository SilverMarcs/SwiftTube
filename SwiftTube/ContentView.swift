//
//  ContentView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 27/09/2025.
//

import SwiftUI

struct ContentView: View {
    @Environment(VideoManager.self) var manager
    @Namespace private var animation
    @State var selection: AppTab = .feed
    
    var body: some View {
        @Bindable var manager = manager
        
        TabView(selection: $selection) {
            Tab("Videos", systemImage: "video", value: .feed) {
                FeedView()
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
    }
}

enum AppTab: String, CaseIterable {
    case feed
    case channels
    case settings
}
