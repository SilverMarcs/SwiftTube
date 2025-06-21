//
//  CustomVideoPlayerView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 21/06/2025.
//

import SwiftUI
import AVKit

struct CustomVideoPlayerView: View {
    let webmStreams: [VideoStreamResponse]
    @State private var selectedStreamIndex = 0
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var showQualityPicker = false
    
    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .aspectRatio(16/9, contentMode: .fit)
            } else if isLoading {
                Rectangle()
                    .fill(.background.secondary)
                    .aspectRatio(16/9, contentMode: .fit)
                    .overlay {
                        ProgressView("Loading video...")
                    }
            } else {
                Rectangle()
                    .fill(.background.secondary)
                    .aspectRatio(16/9, contentMode: .fit)
                    .overlay {
                        ContentUnavailableView(
                            "Unable to load video",
                            systemImage: "exclamationmark.triangle.fill",
                            description: Text("No playable video streams found")
                        )
                    }
            }
            
            // Quality picker overlay
            if webmStreams.count > 1 {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            showQualityPicker.toggle()
                        }) {
                            HStack {
                                Text(webmStreams[selectedStreamIndex].quality ?? "Unknown")
                                Image(systemName: "chevron.down")
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                        }
                        .foregroundStyle(.primary)
                        .padding()
                    }
                    Spacer()
                }
            }
        }
        .onAppear {
            loadVideo()
        }
        .sheet(isPresented: $showQualityPicker) {
            qualityPickerSheet
        }
    }
    
    private var qualityPickerSheet: some View {
        NavigationStack {
            List {
                ForEach(Array(webmStreams.enumerated()), id: \.offset) { index, stream in
                    Button(action: {
                        selectedStreamIndex = index
                        showQualityPicker = false
                        loadVideo()
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(stream.quality ?? "Unknown Quality")
                                    .font(.headline)
                                
                                HStack {
                                    if let width = stream.width, let height = stream.height {
                                        Text("\(width)×\(height)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    if let fps = stream.fps {
                                        Text("•")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text("\(fps)fps")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    if let bitrate = stream.bitrate {
                                        Text("•")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text("\(bitrate / 1000)kbps")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            if index == selectedStreamIndex {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("Video Quality")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showQualityPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private func loadVideo() {
        guard !webmStreams.isEmpty,
              selectedStreamIndex < webmStreams.count,
              let urlString = webmStreams[selectedStreamIndex].url,
              let url = URL(string: urlString) else {
            isLoading = false
            return
        }
        
        isLoading = true
        
        // Create new player with selected stream
        let newPlayer = AVPlayer(url: url)
        
        // Replace the current player
        self.player = newPlayer
        
        // Auto-play the video
        newPlayer.play()
        
        isLoading = false
    }
}
