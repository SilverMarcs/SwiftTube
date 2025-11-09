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
    @Environment(\.scenePhase) var scenePhase
    
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
                .task(id: scenePhase) {
                    if scenePhase == .active {
                        await videoLoader.loadAllChannelVideos()
                        
                        if nativeVideoManager.currentVideo == nil {
                            if let mostRecentVideo = videoLoader.getMostRecentHistoryVideo() {
                                nativeVideoManager.setVideo(mostRecentVideo, autoPlay: false)
                            }
                        }
                    }
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
                .environment(videoLoader)
        }
        .restorationBehavior(.disabled)
        #endif
    }
    
    init() {
        AVPlayer.isObservationEnabled = true
        #if !os(macOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        #endif
    }
}
