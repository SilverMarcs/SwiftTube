//
//  VideoInfoView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 21/06/2025.
//

import SwiftUI
import Kingfisher

struct VideoInfoView: View {
    let video: Video
    let videoDetail: VideoDetail
    @State private var isDescriptionExpanded = false
    
    var body: some View {
        VStack(alignment: .leading) {
            // Video Title
            Text(videoDetail.title)
                .font(.title3)
                .fontWeight(.semibold)
                .multilineTextAlignment(.leading)
            
            // Video Stats (Views, Likes, Published)
            videoStatsSection(for: videoDetail)
            
            // Channel Info
            channelSection(for: videoDetail)
            
            // Description
            if let description = videoDetail.description, !description.isEmpty {
                descriptionSection(description)
            }
            
            // Comments Section
            VideoCommentsView(videoId: video.id)
                .padding(.top, 10)
            
            // Related Videos
//            if !videoDetail.relatedVideos.isEmpty {
//                relatedVideosSection(for: videoDetail)
//            }
        }
    }
    
    private func videoStatsSection(for videoDetail: VideoDetail) -> some View {
        HStack {
            // Views
            Text(videoDetail.viewsText)
                .font(.footnote)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            // Likes and Dislikes
            HStack(spacing: 12) {
                if let likesText = videoDetail.likesText {
                    Label(likesText, systemImage: "hand.thumbsup")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                
                if let dislikesText = videoDetail.dislikesText {
                    Label(dislikesText, systemImage: "hand.thumbsdown")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private func channelSection(for videoDetail: VideoDetail) -> some View {
        ChannelInfoRow(videoDetail: videoDetail)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(.background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func descriptionSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description")
                .font(.headline)
            
            // Parse HTML description if it contains HTML tags
            if description.containsHTML {
                Text(description.htmlToAttributedString(font: .subheadline, color: .primary))
                    .lineLimit(isDescriptionExpanded ? nil : 5)
                    .textSelection(.enabled)
            } else {
                Text(description)
                    .font(.subheadline)
                    .lineLimit(isDescriptionExpanded ? nil : 5)
                    .textSelection(.enabled)
            }
            
            Button(isDescriptionExpanded ? "Show Less" : "Show More") {
                withAnimation {
                    isDescriptionExpanded.toggle()
                }
            }
            .font(.caption)
            .foregroundStyle(.blue)
        }
        .frame(maxWidth: .infinity, alignment: .leading) // Add this line
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(.background.secondary))
    }
}
