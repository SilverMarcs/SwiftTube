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

    @State var selectedTab: TabSelection = .home

    var body: some Scene {
        #if os(macOS)
        macOSScene
        macOSPlayerScene
        #elseif os(tvOS)
        tvOSScene
        #else
        iOSScene
        #endif
    }

    private func coldLaunchLoad() async {
        // Warm the cookie-auth singleton from this post-launch task rather than
        // holding it as an App stored property. As a stored property it was
        // built during App.init() — before the window/appearance existed — and
        // its eager WKWebView pinned the macOS control accent to the system
        // default, leaving sidebar icons system-blue instead of our accent.
        // Touching it here primes the cookie store without that side effect.
        _ = YTCookieAuth.shared

        if ytAuth.isSignedIn {
            // Fresh launches usually arrive with the ~1h OAuth access token
            // expired: loadFromKeychain() nils it, so InnerTubeAPI holds no
            // bearer and every launch fetch went out unauthenticated —
            // personalised home returned no shelves and the feed sat on its
            // spinner until a manual refresh (by which time the background
            // token refresh had landed). Refresh the token and hand it to
            // InnerTubeAPI before any fetch starts.
            if let token = try? await ytAuth.validAccessToken() {
                await InnerTubeAPI.shared.setAuthToken(token)
            }
            await store.refresh()
            videoLoader.mode = .subscriptions
        } else {
            videoLoader.mode = .recommendations
        }
        async let subs: Void = videoLoader.loadAllChannelVideos()
        async let recs: Void = videoLoader.loadRecommendations()
        async let shorts: Void = videoLoader.loadShorts()
        _ = await (subs, recs, shorts)

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
                    ytAuth: ytAuth
                ))
                .task { await coldLaunchLoad() }
                // macOS never suspends the app, but googlevideo URLs expire on
                // the server regardless (~6h) — a player left paused overnight
                // is just as dead as on iOS. scenePhase stays .active while any
                // window is visible, so app re-activation is the signal here.
                .onReceive(NotificationCenter.default.publisher(
                    for: NSApplication.didBecomeActiveNotification
                )) { _ in
                    videoManager.refreshExpiredStream()
                }
        }
        .commands {
            AppCommands(selectedTab: $selectedTab)
        }
    }

    private var macOSPlayerScene: some Scene {
        Window("Media Player", id: "media-player") {
            AVPlayerViewMac()
                .modifier(SharedEnvironment(
                    videoLoader: videoLoader,
                    videoManager: videoManager,
                    store: store,
                    ytAuth: ytAuth
                ))
        }
        .restorationBehavior(.disabled)
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
                    ytAuth: ytAuth
                ))
                .environment(DownloadManager.shared)
                .task { await coldLaunchLoad() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background || phase == .inactive {
                        videoManager.persistCurrentTime()
                    } else if phase == .active {
                        videoManager.refreshExpiredStream()
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
                    ytAuth: ytAuth
                ))
                .task { await coldLaunchLoad() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        videoManager.refreshExpiredStream()
                    }
                }
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