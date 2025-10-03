//
//  ContentView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 27/09/2025.
//

import SwiftUI

struct ContentView: View {
    @Environment(VideoManager.self) var manager
    @Environment(VideoLoader.self) private var videoLoader
    @Environment(UserDefaultsManager.self) private var userDefaults
    @Namespace private var animation
    @State var selection: AppTab = .feed
    
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
        }
        .tabViewSidebarBottomBar {
            MiniPlayerAccessoryView()
        }
        #else
        ZStack(alignment: .top) {
            TabView(selection: $selection) {
                Tab("Videos", systemImage: "video", value: .feed) {
                    FeedView()
                }
                
                Tab("Shorts", systemImage: "play.rectangle.on.rectangle", value: .shorts) {
                    ShortsView()
                }
                
                Tab("Profile", systemImage: "person", value: .profile, role: .search) {
                    ProfileView()
                }
            }
            .tabBarMinimizeBehavior(.onScrollDown)
            .tabViewBottomAccessory {
                MiniPlayerAccessoryView()
                    .matchedTransitionSource(id: "MINIPLAYER", in: animation)
            }
            .sheet(isPresented: $manager.isExpanded) {
                if let video = manager.currentVideo {
                    VideoDetailView(video: video)
                        .navigationTransition(.zoom(sourceID: "MINIPLAYER", in: animation))
                        .presentationBackground(.background)
                        .presentationCornerRadius(0)
                        .presentationDetents([.fraction(7.13/10)])
                        .presentationBackgroundInteraction(.enabled)
                }
            }
            
            // Persistent Video Player Overlay
            if manager.currentVideo != nil {
                VideoPlayerView()
                    .zIndex(manager.isExpanded ? 1000 : -1)
                    .allowsHitTesting(manager.isExpanded)
            }
        }
        #endif
    }
}

enum AppTab: String, CaseIterable {
    case feed
    case shorts
    case profile
}
