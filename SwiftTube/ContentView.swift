//
//  ContentView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 20/06/2025.
//

import SwiftUI

struct ContentView: View {
    @State private var selection: Tabs = .videos
    @Namespace private var namespace
    
    var body: some View {
        TabView(selection: $selection) {
            Tab("Feed", systemImage: "video", value: .videos) {
                VideoFeedTab()
                    .environment(\.videoNameSpace, namespace)
            }
            
            Tab("Subs", systemImage: "person.2", value: .subscriptions) {
               SubscriptionsTab()
            }
            
            Tab(value: .search, role: .search) {
                SearchTab()
                    .environment(\.videoNameSpace, namespace)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        #if !os(macOS)
        .tabBarMinimizeBehavior(.onScrollDown)
        #endif
    }
    
    enum Tabs {
        case videos
        case subscriptions
        case settings
        case search
    }
}
