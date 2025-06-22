//
//  CustomVideoPlayerView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 22/06/2025.
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
            // Video player content
            videoPlayerContent
            
            // Quality selector overlay
            qualityOverlay
        }
        .onAppear {
            setupInitialVideo()
        }
        .sheet(isPresented: $showQualityPicker) {
            qualitySelectionView
        }
    }
    
    @ViewBuilder
    private var videoPlayerContent: some View {
        if let player = player {
            VideoPlayer(player: player)
                .aspectRatio(16/9, contentMode: .fit)
        } else if isLoading {
            loadingView
        } else {
            errorView
        }
    }
    
    private var loadingView: some View {
        Rectangle()
            .fill(.background.secondary)
            .aspectRatio(16/9, contentMode: .fit)
            .overlay {
                VStack {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading video...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
            }
    }
    
    private var errorView: some View {
        Rectangle()
            .fill(.background.secondary)
            .aspectRatio(16/9, contentMode: .fit)
            .overlay {
                ContentUnavailableView(
                    "Unable to load video",
                    systemImage: "exclamationmark.triangle.fill",
                    description: Text("No playable WEBM streams found")
                )
            }
    }
    
    @ViewBuilder
    private var qualityOverlay: some View {
        if webmStreams.count > 1 {
            VStack {
                HStack {
                    Spacer()
                    qualityButton
                }
                Spacer()
            }
        }
    }
    
    private var qualityButton: some View {
        Button {
            showQualityPicker.toggle()
        } label: {
            HStack(spacing: 6) {
                Text(currentQualityText)
                    .font(.caption.weight(.medium))
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .foregroundStyle(.primary)
        .padding()
    }
    
    private var currentQualityText: String {
        guard selectedStreamIndex < webmStreams.count else { return "Unknown" }
        return webmStreams[selectedStreamIndex].quality ?? "Unknown"
    }
    
    private var qualitySelectionView: some View {
        NavigationStack {
            List {
                ForEach(Array(webmStreams.enumerated()), id: \.offset) { index, stream in
                    qualityRow(for: stream, at: index)
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
        .presentationDetents([.medium, .large])
    }
    
    private func qualityRow(for stream: VideoStreamResponse, at index: Int) -> some View {
        Button {
            selectQuality(at: index)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stream.quality ?? "Unknown Quality")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    streamDetailsText(for: stream)
                }
                
                Spacer()
                
                if index == selectedStreamIndex {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.title2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private func streamDetailsText(for stream: VideoStreamResponse) -> some View {
        HStack(spacing: 0) {
            if let width = stream.width, let height = stream.height {
                Text("\(width)×\(height)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if let fps = stream.fps {
                if stream.width != nil {
                    Text(" • ")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("\(fps)fps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if let bitrate = stream.bitrate {
                if stream.width != nil || stream.fps != nil {
                    Text(" • ")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(formatBitrate(bitrate))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func formatBitrate(_ bitrate: Int) -> String {
        if bitrate >= 1_000_000 {
            return String(format: "%.1fMbps", Double(bitrate) / 1_000_000)
        } else {
            return "\(bitrate / 1000)kbps"
        }
    }
    
    private func setupInitialVideo() {
        guard !webmStreams.isEmpty else {
            isLoading = false
            return
        }
        loadVideo(at: 0)
    }
    
    private func selectQuality(at index: Int) {
        selectedStreamIndex = index
        showQualityPicker = false
        loadVideo(at: index)
    }
    
    private func loadVideo(at index: Int) {
        guard index < webmStreams.count,
              let urlString = webmStreams[index].url,
              let url = URL(string: urlString) else {
            isLoading = false
            return
        }
        
        isLoading = true
        
        // Stop current player if exists
        player?.pause()
        
        // Create new player with selected stream
        let newPlayer = AVPlayer(url: url)
        self.player = newPlayer
        
        // Start playing
        newPlayer.play()
        
        isLoading = false
    }
}
