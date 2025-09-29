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
    
    var body: some View {
        @Bindable var manager = manager
        
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
        .fullScreenCover(isPresented: $manager.isExpanded) {
            if let video = manager.currentVideo {
                VideoDetailView(video: video)
                    .safeAreaInset(edge: .top, spacing: 0) {
                        YTPlayerView()
                            .navigationTransition(.zoom(sourceID: "MINIPLAYER", in: animation))
                    }
                    .onAppear {
                        // Handle expansion transition
                        manager.handleViewTransitionComplete()
                    }
            }
        }
        .onChange(of: manager.isExpanded) { _, isExpanded in
            if !isExpanded {
                // Prepare for minimizing transition
                manager.prepareForViewTransition()
            }
        }
        #endif
        .environment(\.openURL, OpenURLAction { url in
            if let videoId = url.youtubeVideoID {
                manager.currentVideo = nil
                Task {
                    do {
                        let video = try await YTService.fetchVideo(byId: videoId)
                        
                        manager.currentVideo = video
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
