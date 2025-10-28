//
//  SwiftTubeApp.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 27/09/2025.
//

import SwiftUI
import AVKit

@main
struct SwiftTubeApp: App {
    #if !os(macOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    
    @State var videoLoader = VideoLoader()

    @State var nativeVideoManager = VideoManager()
    @State var userDefaultsManager = CloudStoreManager.shared
    @State var authManager = GoogleAuthManager()
    @State var selectedTab: TabSelection = .feed
    
    var body: some Scene {
        WindowGroup {
            ContentView(selectedTab: $selectedTab)
                .environment(videoLoader)
                .environment(nativeVideoManager)
                .environment(userDefaultsManager)
                .environment(authManager)
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
                    // Prefetch first 10 regular videos and shorts concurrently after loading/shuffling
                    let regularIDs = Array(videoLoader.videos.prefix(10)).map { $0.id }

                    // Only create shortIDs and prefetch them if NOT on macOS
                    #if !os(macOS)
                    let shortIDs = Array(videoLoader.shortVideos.prefix(10)).map { $0.id }
                    #endif

                    async let a: Void = StreamURLCache.shared.prefetch(ids: regularIDs)

                    // Conditionally prefetch shortIDs
                    #if !os(macOS)
                    async let b: Void = StreamURLCache.shared.prefetch(ids: shortIDs)
                    #endif

                    // Await based on whether 'b' was declared
                    #if !os(macOS)
                    _ = await (a, b)
                    #else
                    _ = await a // Only await 'a' if 'b' wasn't declared
                    #endif
                }
        }
        .commands {
            AppCommands(selectedTab: $selectedTab)
        }
        #if os(macOS)
        Window("Media Player", id: "media-player") {
            AVPlayerViewMac()
                .environment(nativeVideoManager)
                .environment(userDefaultsManager)
        }
        .restorationBehavior(.disabled)
        #endif
    }
    
    init() {
        AVPlayer.isObservationEnabled = true
    }
}
