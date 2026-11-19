//
//  ContentView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 27/09/2025.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @Environment(VideoManager.self) var manager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Binding var selectedTab: TabSelection

    @Namespace private var animation
    #if os(iOS)
    @State private var shorts = ShortsSession()
    #endif

    private var isCompactSize: Bool { horizontalSizeClass == .compact }

    #if os(iOS)
    private var showsAccessory: Bool {
        selectedTab == .shorts ? shorts.feed?.currentVideo != nil : manager.currentVideo != nil
    }
    #endif

    private var primaryTabs: [TabSelection] {
        isCompactSize ? TabSelection.tabBarTabs : TabSelection.sidebarTabs
    }

    var body: some View {
        @Bindable var manager = manager

        TabView(selection: $selectedTab) {
            ForEach(primaryTabs, id: \.self) { tab in
                Tab(tab.title,
                    systemImage: tab.systemImage,
                    value: tab,
                    role: tab == .search ? .search : .none)
                {
                    NavigationStack {
                        tab.tabView
                    }
                }
            }

            if !isCompactSize {
                TabSection {
                    ForEach(TabSelection.sidebarSubscriptionTabs, id: \.self) { tab in
                        Tab(tab.title,
                            systemImage: tab.systemImage,
                            value: tab)
                        {
                            NavigationStack {
                                tab.tabView
                            }
                        }
                    }
                } header: {
                    Text("Subscriptions")
                }

                TabSection {
                    ForEach(TabSelection.sidebarLibraryTabs, id: \.self) { tab in
                        Tab(tab.title,
                            systemImage: tab.systemImage,
                            value: tab)
                        {
                            NavigationStack {
                                tab.tabView
                            }
                        }
                    }
                } header: {
                    Text("Library")
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        #if !os(tvOS)
        .tabViewSearchActivation(.searchTabSelection)
        #endif
        #if os(macOS)
        .tabViewSidebarBottomBar {
            if let video = manager.currentVideo {
                PlayVideoButton(video: video) {
                    MiniPlayerAccessoryView()
                }
            }
        }
        #elseif os(tvOS)
        .environment(\.requestVideoPresentation) {
            manager.isExpanded = true
        }
        .fullScreenCover(isPresented: $manager.isExpanded, onDismiss: {
            manager.playerDidDisappear()
        }) {
            AVPlayerViewTvos()
        }
        #else
        .environment(\.requestVideoPresentation) {
            manager.isExpanded = true
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        #if os(iOS)
        .tabViewBottomAccessory(isEnabled: showsAccessory) {
            if selectedTab == .shorts {
                ShortsAccessoryView(transitionNamespace: animation)
            } else if let video = manager.currentVideo {
                PlayVideoButton(video: video) {
                    MiniPlayerAccessoryView(transitionNamespace: animation)
                }
            }
        }
        .fullScreenCover(isPresented: $shorts.isShowingDetail) {
            if let feed = shorts.feed, let video = feed.currentVideo {
                VideoDetailView(video: video) {
                    ShortDetailPlayerView(player: feed.currentPlayer)
                }
                .navigationTransition(.zoom(sourceID: "MINIPLAYER", in: animation))
            }
        }
        .environment(shorts)
        #else
        .tabViewBottomAccessory(isEnabled: (selectedTab != .shorts && manager.currentVideo != nil)) {
            if let video = manager.currentVideo {
                PlayVideoButton(video: video) {
                    MiniPlayerAccessoryView(transitionNamespace: animation)
                }
            }
        }
        #endif
        .fullScreenCover(isPresented: $manager.isExpanded) {
            if let video = manager.currentVideo {
                VideoDetailView(video: video) {
                    AVPlayerViewIos()
                }
                .navigationTransition(.zoom(sourceID: "MINIPLAYER", in: animation))
            }
        }
        #endif
    }
}
