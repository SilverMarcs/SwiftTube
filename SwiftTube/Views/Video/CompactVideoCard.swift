//
//  WatchLaterVideoCard.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 29/09/2025.
//

import SwiftUI
import SwiftMediaViewer

struct CompactVideoCard: View {
    @Environment(VideoManager.self) var manager
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    let video: Video
    
    var body: some View {
        Button {
            #if os(macOS)
            manager.currentVideo = video
            if !manager.isMediaPlayerWindowOpen {
                openWindow(id: "media-player")
            }
            #else
            if manager.currentVideo?.id == video.id {
                manager.isExpanded = true
            } else {
                manager.currentVideo = video
            }
            #endif
        } label: {
            HStack {
                CachedAsyncImage(url: URL(string: video.thumbnailURL), targetSize: 500)
                    .aspectRatio(16/9, contentMode: .fill)
                    .frame(width: 100)
                    .overlay(alignment: .bottom) {
                        if let progress = video.watchProgressRatio {
                            ProgressView(value: progress)
                                .tint(.accent)
                                #if os(macOS)
                                .controlSize(.mini)
                                #endif
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if let duration = video.duration {
                            Text(duration.formatDuration())
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .foregroundStyle(.white)
                                .background(RoundedRectangle(cornerRadius: 3).fill(.black.secondary))
                                .padding(6)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(video.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(2)
                        
                        Text(video.channel.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .videoContextMenu(video: video, showChannelLink: true)
    }
}
