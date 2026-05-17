//
//  SwiftTubeApp.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 27/09/2025.
//

import SwiftUI
import AVKit

@main
struct CathodeApp: App {
    @Environment(\.scenePhase) var scenePhase

    let videoLoader = VideoLoader()
    let videoManager = VideoManager()
    let store = CloudStoreManager.shared
    let authManager = GoogleAuthManager()

    @State var selectedTab: TabSelection = .feed
    
    var body: some Scene {
        WindowGroup {
            ContentView(selectedTab: $selectedTab)
                .environment(videoLoader)
                .environment(videoManager)
                .environment(store)
                .environment(authManager)
                #if os(iOS)
                .environment(DownloadManager.shared)
                #endif
                .environment(\.openURL, OpenURLAction { url in
                    if let videoId = url.youtubeVideoID {
                        Task {
                            do {
                                let video = try await YTService.fetchVideo(byId: videoId)
                                videoManager.setVideo(video)
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

                        if videoManager.currentVideo == nil {
                            if let mostRecentVideo = videoLoader.getMostRecentHistoryVideo() {
                                videoManager.setVideo(mostRecentVideo, autoPlay: false)
                            }
                        }
                    }
                }
        }
        #if !os(tvOS)
        .commands {
            AppCommands(selectedTab: $selectedTab)
        }
        #endif
        #if os(macOS)
        Window("Media Player", id: "media-player") {
            AVPlayerViewMac()
                .environment(videoManager)
                .environment(store)
                .environment(videoLoader)
        }
        .restorationBehavior(.disabled)
        #endif
    }
    
    init() {
        AVPlayer.isObservationEnabled = true

        // Warm DNS + TLS session + Cloudflare Worker for the extraction server
        // so the first user-clicked video pays less startup latency.
        StreamResolver.prewarm()
        #if !os(macOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback)
        try? session.setActive(true)
        #endif
        #if os(iOS)
        // Register BGContinuedProcessingTask handler before any submit() call.
        DownloadActivityCoordinator.register()
        // Eagerly init so the manager is ready when the first download starts.
        _ = DownloadManager.shared
        #endif
    }
}
