//
//  ContentView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 27/09/2025.
//

import SwiftUI

struct ContentView: View {
    @Environment(VideoManager.self) var manager

    @Binding var selectedTab: TabSelection
    
    @Namespace private var animation
    
    @State private var isPresented = false
    
    var body: some View {
        @Bindable var manager = manager

        TabView(selection: $selectedTab) {
            ForEach(TabSelection.allCases, id: \.self) { tab in
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
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabViewSearchActivation(.searchTabSelection)
        #if os(macOS)
        .tabViewSidebarBottomBar {
            if let video = manager.currentVideo {
                PlayVideoButton(video: video) {
                    MiniPlayerAccessoryView()
                }
            }
        }
        #else
        .environment(\.requestVideoPresentation) {
            isPresented = true
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory(isEnabled: (selectedTab != .shorts && manager.currentVideo != nil)) {
            if let video = manager.currentVideo {
                PlayVideoButton(video: video) {
                    MiniPlayerAccessoryView()
                }
                .matchedTransitionSource(id: "MINIPLAYER", in: animation)
            }
        }
        .fullScreenCover(isPresented: $isPresented) {
            if let video = manager.currentVideo {
                VideoDetailView(video: video, showVideo: true)
                    .navigationTransition(.zoom(sourceID: "MINIPLAYER", in: animation))
            }
        }
        #endif
    }
}
