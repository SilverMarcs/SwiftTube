//
//  ChannelView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 21/06/2025.
//

import SwiftUI

struct ChannelView: View {
    let channel: Channel
    @State private var channelDetails: Channel?
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Channel Header
                VStack(spacing: 12) {
                    AsyncImage(url: channel.thumbnailURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    } placeholder: {
                        Circle()
                            .fill(.background.secondary)
                            .frame(width: 100, height: 100)
                            .overlay {
                                Image(systemName: "person.circle.fill")
                                    .foregroundStyle(.secondary)
                                    .font(.system(size: 50))
                            }
                    }
                    
                    VStack(spacing: 4) {
                        HStack {
                            Text(channel.name)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            if channel.verified {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                        
                        if let subscribersText = channel.subscribersText {
                            Text(subscribersText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
                
                // Channel Description
                if let description = channel.description, !description.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About")
                            .font(.headline)
                        
                        Text(description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }
                
                // Videos Section (placeholder)
                if !channel.videos.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Videos")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        LazyVStack(spacing: 12) {
                            ForEach(channel.videos) { video in
                                VideoRow(video: video)
                                    .padding(.horizontal)
                            }
                        }
                    }
                } else if isLoading {
                    ProgressView("Loading channel details...")
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    ContentUnavailableView(
                        "No videos available",
                        systemImage: "video.slash"
                    )
                    .padding()
                }
            }
        }
        .navigationTitle(channel.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadChannelDetails()
        }
    }
    
    private func loadChannelDetails() async {
        isLoading = true
        let details = await PipedAPI.shared.fetchChannelDetails(channelId: channel.id)
        self.channelDetails = details
        self.isLoading = false
    }
}
