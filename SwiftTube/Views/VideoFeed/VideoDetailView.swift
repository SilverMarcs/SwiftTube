//
//  VideoDetailView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 21/06/2025.
//

import SwiftUI

struct VideoDetailView: View {
    let video: Video
    @State private var videoDetail: VideoDetail?
    @State private var isLoading = true
    @State private var isDescriptionExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isLoading {
                ProgressView("Loading video details...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let videoDetail = videoDetail {
                // Video Title
                Text(videoDetail.title)
                    .font(.title2)
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
                
                // Related Videos
//                if !videoDetail.relatedVideos.isEmpty {
//                    relatedVideosSection(for: videoDetail)
//                }
            } else {
                ContentUnavailableView(
                    "Unable to load video details",
                    systemImage: "exclamationmark.triangle"
                )
            }
        }
        .padding(.horizontal)
        .task {
            await loadVideoDetails()
        }
    }
    
    private func loadVideoDetails() async {
        isLoading = true
        let detail = await PipedAPI.shared.fetchVideoDetail(videoId: video.id)
        self.videoDetail = detail
        self.isLoading = false
    }
    
    private func videoStatsSection(for videoDetail: VideoDetail) -> some View {
        HStack {
            // Views
            Text(videoDetail.viewsText)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            // Likes and Dislikes
            HStack(spacing: 12) {
                if let likesText = videoDetail.likesText {
                    Label(likesText, systemImage: "hand.thumbsup")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if let dislikesText = videoDetail.dislikesText {
                    Label(dislikesText, systemImage: "hand.thumbsdown")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private func channelSection(for videoDetail: VideoDetail) -> some View {
        HStack {
            if let uploaderUrl = video.uploaderAvatar, let url = URL(string: uploaderUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 35, height: 35)
                        .clipShape(Circle())
                } placeholder: {
                    Circle()
                        .fill(.gray.opacity(0.3))
                        .frame(width: 35, height: 35)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(videoDetail.uploader)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    Text(videoDetail.subscribersText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Text("•")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Text(videoDetail.durationText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func descriptionSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Description")
                    .font(.headline)
                Spacer()
                Button(isDescriptionExpanded ? "Show Less" : "Show More") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isDescriptionExpanded.toggle()
                    }
                }
                .font(.caption)
                .foregroundStyle(.blue)
            }
            
            Text(description)
                .font(.subheadline)
                .lineLimit(isDescriptionExpanded ? nil : 3)
                .animation(.easeInOut(duration: 0.3), value: isDescriptionExpanded)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
