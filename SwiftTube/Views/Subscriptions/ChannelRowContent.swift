//
//  ChannelRowContent.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 21/06/2025.
//

import SwiftUI

struct ChannelRowContent: View {
    let channel: Channel
    
    var body: some View {
        NavigationLink(value: channel) {
            HStack(spacing: 12) {
                AsyncImage(url: channel.thumbnailURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                } placeholder: {
                    Circle()
                        .fill(.background.secondary)
                        .frame(width: 60, height: 60)
                        .overlay {
                            Image(systemName: "person")
                                .foregroundStyle(.secondary)
                                .font(.largeTitle)
                        }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(channel.name)
                            .font(.headline)
                            .lineLimit(1)
                        
                        if channel.verified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.blue)
                                .font(.caption)
                        }
                    }
                    
                    if let subscribersText = channel.subscribersText {
                        Text(subscribersText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let description = channel.description {
                        Text(description)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
            }
        }
    }
}
