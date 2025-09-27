//
//  ContentView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 27/09/2025.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.channelStore) var channelStore
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
                    VideoListView()
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
                        ChannelListView()
                    }
                }
            }
            .sheet(isPresented: $showingAddChannel) {
                AddChannelView()
            }
            .task {
                if !channelStore.channels.isEmpty {
                    await channelStore.fetchAllVideos()
                }
            }
        }
    }
}
