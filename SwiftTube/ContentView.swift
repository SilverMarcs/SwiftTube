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
        }
//        .tabViewSidebarBottomBar {
        .overlay(alignment: .bottom) {
            MiniPlayerAccessoryView()
                .frame(maxWidth: 400)
                .glassEffect()
                .padding(10)
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
//            .tabBarMinimizeBehavior(.onScrollDown)
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
                        .presentationDetents([.fraction(isCustomFullscreen ? 0.001 : 7.13/10)])
                        .presentationCompactAdaptation(.none)
                        .presentationBackgroundInteraction(.enabled)
                }
            }
            
            VideoPlayerView(isCustomFullscreen: $isCustomFullscreen)
        }
        #endif
    }
}

enum AppTab: String, CaseIterable {
    case feed
    case shorts
    case profile
}
