//
//  SwiftTubeApp.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 27/09/2025.
//

import SwiftUI

@main
struct SwiftTubeApp: App {
    #if !os(macOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    
    @State var videoLoader = VideoLoader()

    @State var nativeVideoManager = VideoManager()
    @State var userDefaultsManager = UserDefaultsManager.shared
    @State var selectedTab: TabSelection = .feed
    
    var body: some Scene {
        WindowGroup {
            ContentView(selectedTab: $selectedTab)
                .environment(videoLoader)
                .environment(nativeVideoManager)
                .environment(userDefaultsManager)
                .environment(\.openURL, OpenURLAction { url in
                    if let videoId = url.youtubeVideoID {
                        Task {
                            do {
                                let video = try await YTService.fetchVideo(byId: videoId)
                                nativeVideoManager.setVideo(video)
                            } catch {
                                print("Failed to fetch video: \(error)")
                            }
                        }
                        return .handled
                    }
                    return .systemAction
                })
                .task {
                    await videoLoader.loadAllChannelVideos()
                    
                    // Restore most recently watched video from history without autoplay
                    if nativeVideoManager.currentVideo == nil {
                        if let mostRecentVideo = videoLoader.getMostRecentHistoryVideo() {
                            nativeVideoManager.setVideo(mostRecentVideo, autoPlay: false)
                        }
                    }
                }
        }
        .commands {
            AppCommands(selectedTab: $selectedTab)
        }
        #if os(macOS)
        Window("media-player", id: "media-player") {
            MediaPlayerWindowView()
                .environment(nativeVideoManager)
                .environment(userDefaultsManager)
        }
        .restorationBehavior(.disabled)
        .windowResizability(.contentSize)
//        .defaultSize(width: 1024, height: 576)
        #endif
    }
}
