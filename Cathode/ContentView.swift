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

    @State private var isPresented = false

    private var isCompactSize: Bool { horizontalSizeClass == .compact }

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
            isPresented = true
        }
        .fullScreenCover(isPresented: $isPresented, onDismiss: {
            manager.player?.pause()
        }) {
            AVPlayerViewTvos()
        }
        #else
        .environment(\.requestVideoPresentation) {
            isPresented = true
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory(isEnabled: (selectedTab != .shorts && manager.currentVideo != nil)) {
            if let video = manager.currentVideo {
                PlayVideoButton(video: video) {
                    MiniPlayerAccessoryView(transitionNamespace: animation)
                }
            }
        }
        .fullScreenCover(isPresented: $isPresented) {
            if let video = manager.currentVideo {
                VideoDetailView(video: video, showVideo: true)
                  // .accentColor(.accent)
                    .navigationTransition(.zoom(sourceID: "MINIPLAYER", in: animation))
            }
        }
        #endif
    }
}
