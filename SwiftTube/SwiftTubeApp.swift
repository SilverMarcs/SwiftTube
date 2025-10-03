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
    @State var videoManager = VideoManager()
    @State var shortsManager = ShortsManager()
    @State var userDefaultsManager = UserDefaultsManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(videoLoader)
                .environment(videoManager)
                .environment(shortsManager)
                .environment(userDefaultsManager)
                .environment(\.openURL, OpenURLAction { url in
                    if let videoId = url.youtubeVideoID {
                        // TODO: remove teh dismiss function
                        videoManager.dismiss()
                        Task {
                            do {
                                let video = try await YTService.fetchVideo(byId: videoId)
                                videoManager.currentVideo = video
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
                    if videoManager.currentVideo == nil {
                        if let mostRecentVideo = videoLoader.getMostRecentHistoryVideo() {
                            videoManager.setVideoWithoutAutoplay(mostRecentVideo)
                        }
                    }
                }
        }
        
        #if os(macOS)
        WindowGroup(id: "media-player") {
            VideoPlayerView()
                .background(.black, ignoresSafeAreaEdges: .all)
                .gesture(WindowDragGesture())
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
                .navigationTitle(videoManager.currentVideo?.title ?? "Loading")
                .preferredColorScheme(.dark)
                .onDisappear {
                    videoManager.dismiss()
                }
        }
        .restorationBehavior(.disabled)
        .windowResizability(.contentSize)
//        .defaultSize(width: 1280, height: 720)
        .environment(videoManager)
        #endif
    }
}
