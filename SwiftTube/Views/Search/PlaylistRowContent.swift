//
//  PlaylistRowContent.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 21/06/2025.
//

import SwiftUI

struct PlaylistRowContent: View {
    let playlist: Playlist
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: playlist.thumbnailURL) { image in
                image
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fit)
                    .frame(width: 80, height: 45)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.background.secondary)
                    .frame(width: 80, height: 45)
                    .overlay {
                        Image(systemName: "list.bullet.rectangle")
                            .foregroundStyle(.secondary)
                    }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.headline)
                    .lineLimit(2)
                
                if let uploaderName = playlist.uploaderName {
                    Text(uploaderName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                if let videoCountText = playlist.videoCountText {
                    Text(videoCountText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(.background.secondary, in: .rect(cornerRadius: 12))
    }
}
