//
//  ContentView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 27/09/2025.
//

import SwiftUI
import SwiftMediaViewer

struct ContentView: View {
    @Environment(VideoManager.self) var manager
    @Namespace private var animation
    @State var selection: AppTab = .feed
    @State private var isCustomFullscreen = false
    
    var body: some View {
        @Bindable var manager = manager
        
        #if os(macOS)
        TabView(selection: $selection) {
            Tab("Videos", systemImage: "video", value: .feed) {
                FeedView()
            }

            Tab("Profile", systemImage: "person", value: .profile) {
                ProfileView()
            }
            
            Tab("Search", systemImage: "magnifyingglass", value: .search) {
                SearchView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabViewSidebarBottomBar {
//        .overlay(alignment: .bottom) {
            MiniPlayerAccessoryView()
//                .frame(maxWidth: 400)
        }
        #else
        TabView(selection: $selection) {
            Tab("Videos", systemImage: "video", value: .feed) {
                FeedView()
                    .safeAreaBar(edge: .bottom) {
                        MiniPlayerAccessoryView()
                            .matchedTransitionSource(id: "MINIPLAYER", in: animation)
                    }
            }
            
            Tab("Shorts", systemImage: "play.rectangle.on.rectangle", value: .shorts) {
                ShortsView()
            }

            Tab("Profile", systemImage: "person", value: .profile) {
                ProfileView()
                    .safeAreaBar(edge: .bottom) {
                        MiniPlayerAccessoryView()
                            .matchedTransitionSource(id: "MINIPLAYER", in: animation)
                    }
            }
            
            
            Tab("Search", systemImage: "magnifyingglass", value: .search) {
                SearchView()
                    .safeAreaBar(edge: .bottom) {
                        MiniPlayerAccessoryView()
                            .matchedTransitionSource(id: "MINIPLAYER", in: animation)
                    }
            }
        }
//        .tabBarMinimizeBehavior(.onScrollDown)
//        .tabViewBottomAccessory {
//        .safeAreaBar(edge: .bottom) {
//            MiniPlayerAccessoryView()
//                .matchedTransitionSource(id: "MINIPLAYER", in: animation)
//        }
        .fullScreenCover(isPresented: $manager.isExpanded) {
            if let video = manager.currentVideo {
                VideoDetailView(video: video, showVideo: true)
                    .navigationTransition(.zoom(sourceID: "MINIPLAYER", in: animation))
            }
        }
        #endif
    }
}

enum AppTab: String, CaseIterable {
    case feed
    case search
    case shorts
    case profile
}
