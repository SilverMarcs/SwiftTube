//
//  PlaylistRowContent.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 21/06/2025.
//

import SwiftUI
import Kingfisher

struct PlaylistRowContent: View {
    let playlist: Playlist
    
    var body: some View {
        HStack(spacing: 12) {
            KFImage(playlist.thumbnailURL)
                .downsampling(size: CGSize(width: 160, height: 90))
                .serialize(as: .JPEG)
                .fade(duration: 0.2)
                .resizable()
                .aspectRatio(16/9, contentMode: .fit)
                .frame(width: 80, height: 45)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
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
