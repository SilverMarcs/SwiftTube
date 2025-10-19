//
//  ContentView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 27/09/2025.
//

import SwiftUI
import SwiftMediaViewer

struct ContentView: View {
    @Environment(VideoManager.self) var manager

    @Binding var selectedTab: TabSelection
    @State private var isCustomFullscreen = false
    
    @Namespace private var animation
    
    var body: some View {
        @Bindable var manager = manager

        TabView(selection: $selectedTab) {
            ForEach(TabSelection.allCases, id: \.self) { tab in
                Tab(tab.title, systemImage: tab.systemImage, value: tab, role: tab == .search ? .search : .none) {
                    tab.tabView
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        #if os(macOS)
        .tabViewSidebarBottomBar {
            MiniPlayerAccessoryView()
        }
        #else
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            MiniPlayerAccessoryView()
                .matchedTransitionSource(id: "MINIPLAYER", in: animation)
        }
        .fullScreenCover(isPresented: $manager.isExpanded) {
            if let video = manager.currentVideo {
                NavigationStack {
                    VideoDetailView(video: video)
                        .safeAreaBar(edge: .top) {
                            NativeVideoPlayerView()
                        }
                }
                .navigationTransition(.zoom(sourceID: "MINIPLAYER", in: animation))
            }
        }
        #endif
    }
}
