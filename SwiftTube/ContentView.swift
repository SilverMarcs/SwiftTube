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
            .task {
                await videoLoader.loadAllChannelVideos()
                
                // Restore most recently watched video from history without autoplay
                if manager.currentVideo == nil {
                    let historyVideos = videoLoader.videos.filter { userDefaults.isInHistory($0.id) }
                        .sorted {
                            let time1 = userDefaults.getWatchTime($0.id) ?? .distantPast
                            let time2 = userDefaults.getWatchTime($1.id) ?? .distantPast
                            return time1 > time2
                        }
                    
                    if let mostRecentVideo = historyVideos.first {
                        manager.setVideoWithoutAutoplay(mostRecentVideo)
                    }
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
                        manager.currentVideo = video
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
