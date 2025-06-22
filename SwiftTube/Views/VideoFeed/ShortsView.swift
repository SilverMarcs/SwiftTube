//
//  ShortsView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 21/06/2025.
//

import SwiftUI
import YouTubePlayerKit

struct ShortsView: View {
    let videos: [Video]
    @State private var currentIndex = 0
    
    var body: some View {
        TabView(selection: $currentIndex) {
            ForEach(videos) { video in
                ShortVideoCard(video: video)
                    .tag(video.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
//        .tabViewStyle(PageTabViewStyle())
//        .rotationEffect(.degrees(90))
    }
}

struct ShortVideoCard: View {
    let video: Video
    @State private var isShowingDescription = false
    
    var youTubePlayer: YouTubePlayer { YouTubePlayer(
        // Possible values: .video, .videos, .playlist, .channel
        source: .video(id: video.id),
        // The parameters of the player
        parameters: .init(
            autoPlay: true,
            showControls: true,
        ),
        // The configuration of the underlying web view
        configuration: .init(
            fullscreenMode: .system,
            allowsInlineMediaPlayback: true,
        ))
    }
    
    
    var body: some View {
//        ZStack {
            YouTubePlayerView(youTubePlayer) { state in
                switch state {
                case .idle:
                    Rectangle()
                        .fill(.background.secondary)
                        .overlay {
                            ProgressView()
                        }
                case .ready:
                    EmptyView()
                case .error(let error):
                    ContentUnavailableView(
                        "Error",
                        systemImage: "exclamationmark.triangle.fill",
                        description: Text("YouTube player couldn't be loaded: \(error.localizedDescription)")
                    )
                }
            }
            .aspectRatio(9/16, contentMode: .fit)
            .onDisappear {
                Task {
                    try? await youTubePlayer.stop()
                }
            }
            
            
            // Gradient overlay for better text readability
//            LinearGradient(
//                colors: [.clear, .clear, .black.opacity(0.8)],
//                startPoint: .top,
//                endPoint: .bottom
//            )
//            
//            // Content overlay
//            VStack {
//                Spacer()
//                
//                HStack(alignment: .bottom) {
//                    // Left side - video info
//                    VStack(alignment: .leading, spacing: 8) {
//                        Text(video.title)
//                            .font(.headline)
//                            .foregroundStyle(.white)
//                            .lineLimit(isShowingDescription ? nil : 2)
//                            .multilineTextAlignment(.leading)
//                        
//                        HStack(spacing: 4) {
//                            if let uploaderUrl = video.uploaderAvatar, let url = URL(string: uploaderUrl) {
//                                AsyncImage(url: url) { image in
//                                    image
//                                        .resizable()
//                                        .aspectRatio(contentMode: .fill)
//                                        .frame(width: 24, height: 24)
//                                        .clipShape(Circle())
//                                } placeholder: {
//                                    Circle()
//                                        .fill(.white.opacity(0.3))
//                                        .frame(width: 24, height: 24)
//                                }
//                            }
//                            
//                            Text(video.uploaderName)
//                                .font(.subheadline)
//                                .foregroundStyle(.white.opacity(0.9))
//                            
//                            Text("•")
//                                .foregroundStyle(.white.opacity(0.7))
//                            
//                            Text(video.viewsText)
//                                .font(.subheadline)
//                                .foregroundStyle(.white.opacity(0.9))
//                        }
//                        
//                        Button(isShowingDescription ? "Show less" : "Show more") {
//                            withAnimation(.easeInOut(duration: 0.2)) {
//                                isShowingDescription.toggle()
//                            }
//                        }
//                        .font(.caption)
//                        .foregroundStyle(.white.opacity(0.8))
//                    }
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                    
//                    Spacer()
//                    
//                    // Right side - action buttons
//                    VStack(spacing: 20) {
//                        // Play/Watch button
//                        NavigationLink(value: video) {
//                            VStack(spacing: 4) {
//                                Circle()
//                                    .fill(.white.opacity(0.9))
//                                    .frame(width: 48, height: 48)
//                                    .overlay {
//                                        Image(systemName: "play.fill")
//                                            .font(.title2)
//                                            .foregroundStyle(.black)
//                                    }
//                                
//                                Text("Watch")
//                                    .font(.caption2)
//                                    .foregroundStyle(.white)
//                            }
//                        }
//                        .buttonStyle(.plain)
//                        
//                        // Like button
//                        Button {
//                            // Like action
//                        } label: {
//                            VStack(spacing: 4) {
//                                Circle()
//                                    .fill(.white.opacity(0.2))
//                                    .frame(width: 48, height: 48)
//                                    .overlay {
//                                        Image(systemName: "heart")
//                                            .font(.title2)
//                                            .foregroundStyle(.white)
//                                    }
//                                
//                                Text("Like")
//                                    .font(.caption2)
//                                    .foregroundStyle(.white)
//                            }
//                        }
//                        .buttonStyle(.plain)
//                        
//                        // Share button
//                        Button {
//                            // Share action
//                        } label: {
//                            VStack(spacing: 4) {
//                                Circle()
//                                    .fill(.white.opacity(0.2))
//                                    .frame(width: 48, height: 48)
//                                    .overlay {
//                                        Image(systemName: "square.and.arrow.up")
//                                            .font(.title2)
//                                            .foregroundStyle(.white)
//                                    }
//                                
//                                Text("Share")
//                                    .font(.caption2)
//                                    .foregroundStyle(.white)
//                            }
//                        }
//                        .buttonStyle(.plain)
//                    }
//                }
//                .padding(.horizontal, 16)
//                .padding(.bottom, 40)
//            }
//        }
    }
}
