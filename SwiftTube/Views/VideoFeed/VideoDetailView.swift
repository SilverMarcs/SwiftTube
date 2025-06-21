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
//        let detail = await PipedAPI.shared.fetchVideoDetail(for: video)
//        await MainActor.run {
//            self.videoDetail = detail
//            self.isLoading = false
//        }
    }
    
    private func videoStatsSection(for videoDetail: VideoDetail) -> some View {
        HStack {
            // Views
            Label(videoDetail.viewsText + " views", systemImage: "eye")
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
            VStack(alignment: .leading, spacing: 4) {
                Text(videoDetail.author)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    if let subscriberCount = videoDetail.channelSubscriberCount {
                        Text("\(subscriberCount.formatted()) subscribers")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    if !videoDetail.published.isEmpty {
                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        
                        Text(videoDetail.published)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
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
    
    
    
//    private func relatedVideosSection(for videoDetail: VideoDetail) -> some View {
//        VStack(alignment: .leading, spacing: 8) {
//            Text("Related Videos")
//                .font(.headline)
//            
//            LazyVStack(spacing: 12) {
//                ForEach(videoDetail.relatedVideos.prefix(5)) { relatedVideo in
//                    HStack(spacing: 12) {
//                        AsyncImage(url: relatedVideo.thumbnailURL) { image in
//                            image
//                                .resizable()
//                                .aspectRatio(contentMode: .fill)
//                        } placeholder: {
//                            Rectangle()
//                                .fill(.background.tertiary)
//                        }
//                        .frame(width: 120, height: 68)
//                        .clipShape(RoundedRectangle(cornerRadius: 8))
//                        .overlay(alignment: .bottomTrailing) {
//                            if relatedVideo.duration > 0 {
//                                Text(relatedVideo.durationText)
//                                    .font(.caption2)
//                                    .fontWeight(.semibold)
//                                    .padding(.horizontal, 4)
//                                    .padding(.vertical, 2)
//                                    .background(.black.opacity(0.8))
//                                    .foregroundStyle(.white)
//                                    .clipShape(RoundedRectangle(cornerRadius: 3))
//                                    .padding(4)
//                            }
//                        }
//                        
//                        VStack(alignment: .leading, spacing: 4) {
//                            Text(relatedVideo.title)
//                                .font(.subheadline)
//                                .lineLimit(2)
//                                .multilineTextAlignment(.leading)
//                            
//                            Text(relatedVideo.author)
//                                .font(.caption)
//                                .foregroundStyle(.secondary)
//                            
//                            HStack {
//                                Text(relatedVideo.viewsText + " views")
//                                    .font(.caption2)
//                                    .foregroundStyle(.secondary)
//                                
//                                if !relatedVideo.published.isEmpty {
//                                    Text("•")
//                                        .font(.caption2)
//                                        .foregroundStyle(.secondary)
//                                    
//                                    Text(relatedVideo.published)
//                                        .font(.caption2)
//                                        .foregroundStyle(.secondary)
//                                }
//                            }
//                        }
//                        
//                        Spacer()
//                    }
//                }
//            }
//        }
//        .padding(.vertical, 12)
//        .padding(.horizontal, 12)
//        .background(.background.secondary)
//        .clipShape(RoundedRectangle(cornerRadius: 12))
//    }
}
//
//#Preview {
//    ScrollView {
//        VideoDetailView(video: Video(
//            id: "dQw4w9WgXcQ",
//            title: "Rick Astley - Never Gonna Give You Up (Official Video)",
//            author: "Rick Astley",
//            duration: 212,
//            published: "2 days ago",
//            views: 1_234_567_890,
//            channelSubscriberCount: 2_800_000
//        ))
//    }
//}
