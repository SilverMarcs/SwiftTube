//
//  ChannelInfoRow.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 24/06/2025.
//

import SwiftUI
import Kingfisher

struct ChannelInfoRow: View {
    let videoDetail: VideoDetail
    
    var body: some View {
        HStack {
            if let uploaderUrl = videoDetail.uploaderAvatar, let url = URL(string: uploaderUrl) {
                KFImage(url)
                    .downsampling(size: CGSize(width: 70, height: 70))
                    .serialize(as: .JPEG)
                    .fade(duration: 0.2)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 35, height: 35)
                    .clipShape(Circle())
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(videoDetail.uploader)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(videoDetail.subscribersText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
}
