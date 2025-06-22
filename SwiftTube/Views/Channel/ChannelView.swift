//
//  ChannelView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 21/06/2025.
//

import SwiftUI
import Kingfisher

struct ChannelView: View {
    let channel: Channel
    @State private var channelDetails: Channel?
    @State private var isLoading = true
    @State private var isSubscribed = false
    @State private var isCheckingSubscription = true
    @State private var isSubscriptionLoading = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Channel Header
                VStack(spacing: 12) {
                    KFImage(channel.thumbnailURL)
                        .downsampling(size: CGSize(width: 200, height: 200))
                        .serialize(as: .JPEG)
                        .fade(duration: 0.2)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                    
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
                        
                        // Subscribe/Unsubscribe Button
                        if isCheckingSubscription {
                            ProgressView("Checking subscription...")
                                .font(.caption)
                        } else {
                            Button(action: {
                                Task {
                                    await toggleSubscription()
                                }
                            }) {
                                HStack {
                                    Image(systemName: isSubscribed ? "person.badge.minus" : "person.badge.plus")
                                    Text(isSubscribed ? "Unsubscribe" : "Subscribe")
                                }
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(isSubscribed ? .red : .blue)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isSubscribed ? .red : .blue, lineWidth: 1)
                                )
                            }
                            .disabled(isSubscriptionLoading)
                            .opacity(isSubscriptionLoading ? 0.6 : 1.0)
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
            await checkSubscriptionStatus()
        }
    }
    
    private func loadChannelDetails() async {
        isLoading = true
        let details = await PipedAPI.shared.fetchChannelDetails(channelId: channel.id)
        self.channelDetails = details
        self.isLoading = false
    }
    
    private func checkSubscriptionStatus() async {
        isCheckingSubscription = true
        // TODO: Cache subscriptions to avoid repeated API calls
        let subscriptions = await PipedAPI.shared.fetchSubscriptions()
        isSubscribed = subscriptions.contains { $0.id == channel.id }
        isCheckingSubscription = false
    }
    
    private func toggleSubscription() async {
        isSubscriptionLoading = true
        
        let success: Bool
        if isSubscribed {
            success = await PipedAPI.shared.unsubscribe(from: channel.id)
        } else {
            success = await PipedAPI.shared.subscribe(to: channel.id)
        }
        
        if success {
            isSubscribed.toggle()
        }
        
        isSubscriptionLoading = false
    }
}
