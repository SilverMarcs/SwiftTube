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
    let store = LibraryStore.shared
    let ytAuth = YTTVAuthManager.shared
    let cookieAuth = YTCookieAuth.shared

    @State var selectedTab: TabSelection = .feed

    var body: some Scene {
        #if os(macOS)
        macOSScene
        Window("Media Player", id: "media-player") {
            AVPlayerViewMac()
                .modifier(SharedEnvironment(
                    videoLoader: videoLoader,
                    videoManager: videoManager,
                    store: store,
                    ytAuth: ytAuth,
                    cookieAuth: cookieAuth
                ))
        }
        .restorationBehavior(.disabled)
        #elseif os(tvOS)
        tvOSScene
        #else
        iOSScene
        #endif
    }

    private func coldLaunchLoad() async {
        if ytAuth.isSignedIn {
            await store.refresh()
            videoLoader.mode = .subscriptions
        } else {
            videoLoader.mode = .recommendations
        }
        async let subs: Void = videoLoader.loadAllChannelVideos()
        async let recs: Void = videoLoader.loadRecommendations()
        _ = await (subs, recs)

        if videoManager.currentVideo == nil,
           let mostRecentVideo = videoLoader.getMostRecentHistoryVideo() {
            videoManager.setVideo(mostRecentVideo, autoPlay: false)
        }
    }

    #if os(macOS)
    private var macOSScene: some Scene {
        Window("Cathode", id: "main") {
            ContentView(selectedTab: $selectedTab)
                .modifier(SharedEnvironment(
                    videoLoader: videoLoader,
                    videoManager: videoManager,
                    store: store,
                    ytAuth: ytAuth,
                    cookieAuth: cookieAuth
                ))
                .task { await coldLaunchLoad() }
        }
        .commands {
            AppCommands(selectedTab: $selectedTab)
        }
    }
    #endif

    #if os(iOS)
    private var iOSScene: some Scene {
        WindowGroup {
            ContentView(selectedTab: $selectedTab)
                .modifier(SharedEnvironment(
                    videoLoader: videoLoader,
                    videoManager: videoManager,
                    store: store,
                    ytAuth: ytAuth,
                    cookieAuth: cookieAuth
                ))
                .environment(DownloadManager.shared)
                .task(id: scenePhase) {
                    if scenePhase == .active {
                        await coldLaunchLoad()
                    } else if scenePhase == .background || scenePhase == .inactive {
                        videoManager.persistCurrentTime()
                    }
                }
        }
        .commands {
            AppCommands(selectedTab: $selectedTab)
        }
    }
    #endif

    #if os(tvOS)
    private var tvOSScene: some Scene {
        WindowGroup {
            ContentView(selectedTab: $selectedTab)
                .modifier(SharedEnvironment(
                    videoLoader: videoLoader,
                    videoManager: videoManager,
                    store: store,
                    ytAuth: ytAuth,
                    cookieAuth: cookieAuth
                ))
                .task { await coldLaunchLoad() }
                .onOpenURL { url in
                    handleTopShelfURL(url)
                }
        }
    }

    private func handleTopShelfURL(_ url: URL) {
        guard let deepLink = TopShelfDeepLink.parse(url) else { return }
        Task {
            do {
                let info = try await InnerTubeAPI.shared.fetchPlayerInfo(videoId: deepLink.itemID)
                videoManager.setVideo(info.video, autoPlay: deepLink.action == .play)
            } catch {
                print("Failed to handle Top Shelf deep link: \(error)")
            }
        }
    }
    #endif

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

private struct SharedEnvironment: ViewModifier {
    let videoLoader: VideoLoader
    let videoManager: VideoManager
    let store: LibraryStore
    let ytAuth: YTTVAuthManager
    let cookieAuth: YTCookieAuth

    func body(content: Content) -> some View {
        content
            .environment(videoLoader)
            .environment(videoManager)
            .environment(store)
            .environment(ytAuth)
            .environment(cookieAuth)
            .accentColor(.accent)
            .environment(\.openURL, OpenURLAction { url in
                if let videoId = url.youtubeVideoID {
                    Task {
                        do {
                            let info = try await InnerTubeAPI.shared.fetchPlayerInfo(videoId: videoId)
                            videoManager.setVideo(info.video)
                        } catch {
                            print("Failed to fetch video: \(error)")
                        }
                    }
                    return .handled
                }
                return .systemAction
            })
            .task(id: ytAuth.isSignedIn) {
                // Re-fetch the feed and the library when sign-in completes
                // — the cold-launch load fired before auth was restored
                // and left the lists empty.
                if ytAuth.isSignedIn {
                    videoLoader.mode = .subscriptions
                    await store.refresh()
                    await videoLoader.loadAllChannelVideos()
                } else {
                    videoLoader.mode = .recommendations
                    videoLoader.clearSubscriptions()
                    await videoLoader.loadRecommendations()
                }
            }
    }
}
