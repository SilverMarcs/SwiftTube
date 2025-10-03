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
            #endif
            
            // Persistent Video Player Overlay
            if manager.currentVideo != nil {
                PersistentVideoPlayerOverlay()
                    .zIndex(manager.isExpanded ? 1000 : -1)
                    .allowsHitTesting(manager.isExpanded)
            }
        }
        .environment(\.openURL, OpenURLAction { url in
            if let videoId = url.youtubeVideoID {
                manager.dismiss()
                Task {
                    do {
                        let video = try await YTService.fetchVideo(byId: videoId)
                        
                        manager.startPlaying(video)
                        manager.isExpanded = true
                    } catch {
                        print("Failed to fetch video: \(error)")
                    }
                }
                return .handled
            }
            return .systemAction
        })
    }
}

enum AppTab: String, CaseIterable {
    case feed
    case shorts
    case profile
}
