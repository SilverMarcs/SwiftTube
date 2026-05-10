//
//  ContentView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 27/09/2025.
//

import SwiftUI

struct ContentView: View {
    @Environment(VideoManager.self) var manager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Binding var selectedTab: TabSelection

    @Namespace private var animation

    @State private var isPresented = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("showGoogleAuth") private var showGoogleAuth = false
    @AppStorage("tvOSNavigationStyle") private var tvNavigationStyleSetting = TVNavigationStyle.tabBar

    private var isCompactSize: Bool { horizontalSizeClass == .compact }

    private var primaryTabs: [TabSelection] {
        isCompactSize ? TabSelection.compactTabs : TabSelection.extendedTabs
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
                    ForEach(TabSelection.extendedSubscriptionTabs, id: \.self) { tab in
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
                    ForEach(TabSelection.extendedLibraryTabs, id: \.self) { tab in
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
        #if os(tvOS)
        .tvNavigationStyle(tvNavigationStyleSetting)
        #else
        .tabViewStyle(.sidebarAdaptable)
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
        .fullScreenCover(isPresented: $isPresented) {
            ZStack {
                Color.black
                if let player = manager.player {
                    AVPlayerTvos(player: player)
                }
                if manager.isSetting || manager.player == nil {
                    UniversalProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.black)
                }
            }
            .ignoresSafeArea()
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
                    .navigationTransition(.zoom(sourceID: "MINIPLAYER", in: animation))
            }
        }
        #endif
        .sheet(isPresented: Binding(
            get: { !hasCompletedOnboarding },
            set: { if !$0 { hasCompletedOnboarding = true } }
        )) {
            OnboardingView()
        }
    }
}
