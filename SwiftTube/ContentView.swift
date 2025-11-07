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
    @State private var searchText: String = ""
    
    var body: some View {
        @Bindable var manager = manager

        TabView(selection: $selectedTab) {
            ForEach(TabSelection.allCases, id: \.self) { tab in
                Tab(tab.title,
                    systemImage: tab.systemImage,
                    value: tab,
                    role: tab == .search ? .search : .none)
                {
                    switch tab {
                    case .search:
                        SearchView(searchText: $searchText)
                    default:
                        tab.tabView
                    }
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabViewSearchActivation(.searchTabSelection)
        .searchable(text: $searchText, placement: .toolbarPrincipal, prompt: "Search videos or channels")
        #if os(macOS)
        .tabViewSidebarBottomBar {
            if let video = manager.currentVideo {
                PlayVideoButton(video: video) {
                    MiniPlayerAccessoryView()
                }
            }
        }
        #else
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            if selectedTab != .shorts {
                MiniPlayerAccessoryView()
                    .matchedTransitionSource(id: "MINIPLAYER", in: animation)
                    .onTapGesture {
                        manager.isExpanded = true
                    }
            }
        }
        .fullScreenCover(isPresented: $manager.isExpanded) {
            if let video = manager.currentVideo {
                VideoDetailView(video: video, showVideo: true)
                    .navigationTransition(.zoom(sourceID: "MINIPLAYER", in: animation))
            }
        }
        #endif
    }
}
