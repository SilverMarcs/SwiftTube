//
//  VideoRowContent.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 21/06/2025.
//

import SwiftUI

struct VideoRowContent: View {
    let video: Video
    let namespace: Namespace.ID
    
    var body: some View {
        NavigationLink(value: video) {
            VStack(alignment: .leading, spacing: 10) {
                AsyncImage(url: video.thumbnailURL) { image in
                    image
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
                } placeholder: {
                    Rectangle()
                        .fill(.background.secondary)
                        .aspectRatio(16/9, contentMode: .fit)
                        .overlay {
                            ProgressView()
                        }
                }
                .matchedTransitionSource(id: "video-\(video.id)", in: namespace)
                .padding(.horizontal, -12)
                .padding(.top, -12)
                
                Text(video.title)
                    .font(.headline)
                    .lineLimit(2)
                
                HStack {
                    if let uploaderUrl = video.uploaderAvatar, let url = URL(string: uploaderUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 22, height: 22)
                                .clipShape(Circle())
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 22, height: 22)
                                .foregroundStyle(.secondary)
                        }
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
