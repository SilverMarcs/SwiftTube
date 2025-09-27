//
//  ContentView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 27/09/2025.
//

import SwiftUI

struct ContentView: View {
    @State private var channelStore = ChannelStore()
    @State private var showingAddChannel = false
    
    var body: some View {
        NavigationStack {
            VStack {
                if channelStore.channels.isEmpty {
                    ContentUnavailableView(
                        "No Channels",
                        systemImage: "tv",
                        description: Text("Add some YouTube channels to get started")
                    )
                } else {
                    VideoListView(channelStore: channelStore)
                }
            }
            .navigationTitle("YouTube Feed")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Channel") {
                        showingAddChannel = true
                    }
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    NavigationLink("Channels") {
                        ChannelListView(channelStore: channelStore)
                    }
                }
            }
            .sheet(isPresented: $showingAddChannel) {
                AddChannelView(channelStore: channelStore)
            }
            .task {
                if !channelStore.channels.isEmpty {
                    await channelStore.fetchAllVideos()
                }
            }
        }
    }
}
