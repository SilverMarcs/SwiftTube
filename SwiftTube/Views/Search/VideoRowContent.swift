//
//  VideoRowContent.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 21/06/2025.
//

import SwiftUI
import Kingfisher

struct VideoRowContent: View {
    let video: Video
    let namespace: Namespace.ID
    
    var body: some View {
        NavigationLink(value: video) {
            VStack(alignment: .leading, spacing: 10) {
                KFImage(video.thumbnailURL)
                    .downsampling(size: CGSize(width: 640, height: 360))
                    .serialize(as: .JPEG)
                    .fade(duration: 0.2)
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fit)
                    .aspectRatio(contentMode: .fit)
                    .overlay(alignment: .bottomTrailing) {
                        Text(video.durationText)
                            .font(.caption)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .foregroundStyle(.white)
                            .background(RoundedRectangle(cornerRadius: 4).fill(.black.secondary))
                            .padding(10)
                    }
                .matchedTransitionSource(id: "video-\(video.id)", in: namespace)
                .padding(.horizontal, -12)
                .padding(.top, -12)
                
                Text(video.title)
                    .font(.headline)
                    .lineLimit(2)
                
                HStack {
                    if let uploaderUrl = video.uploaderAvatar, let url = URL(string: uploaderUrl) {
                        KFImage(url)
                            .downsampling(size: CGSize(width: 44, height: 44))
                            .serialize(as: .JPEG)
                            .fade(duration: 0.2)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 22, height: 22)
                            .clipShape(Circle())
                    }
                    
                    Text(video.uploaderName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()

                    Text(video.viewsText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .background(.background.secondary, in: .rect(cornerRadius: 16))
        }
    }
}
