// VideoDetailView.swift
import SwiftUI

struct VideoDetailView: View {
    @Environment(\.openURL) var openURL
    @Environment(\.channelStore) var channelStore
    let videoId: String
    
    @State private var videoDetail: VideoDetail?
    @State private var isLoading = true
    @State private var error: Error?
    
    var body: some View {
        ScrollView {
            if let videoDetail = videoDetail {
                VStack(alignment: .leading, spacing: 16) {
                    // Thumbnail
                    AsyncImage(url: URL(string: videoDetail.thumbnailURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fit)
                    } placeholder: {
                        Rectangle()
                            .fill(.secondary.opacity(0.3))
                            .aspectRatio(16/9, contentMode: .fit)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    VStack(alignment: .leading, spacing: 12) {
                        // Title
                        Text(videoDetail.title)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        // Channel & Date
                        HStack {
                            Text(videoDetail.channelTitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Text(videoDetail.publishedAt, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        // Stats Row
                        HStack {
                            Label(videoDetail.viewCount + " views", systemImage: "eye")
                            
                            if let likes = videoDetail.likeCount {
                                Label(likes, systemImage: "hand.thumbsup")
                            }
                            
                            if let comments = videoDetail.commentCount {
                                Label(comments, systemImage: "bubble.left")
                            }
                            
                            Spacer()
                            
                            Text(videoDetail.duration)
                                .font(.caption.monospaced())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(.secondary.opacity(0.2))
                                .clipShape(Capsule())
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        
                        // Technical Info
                        HStack {
                            Text(videoDetail.definition)
                            
                            if videoDetail.caption {
                                Text("CC")
                                    .fontWeight(.semibold)
                            }
                            
                            Text(videoDetail.privacyStatus.capitalized)
                            
                            Spacer()
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        
                        Divider()
                        
                        // Description
                        Text("Description")
                            .font(.headline)
                        
                        Text(videoDetail.description)
                            .font(.body)
                        
                        // Tags
                        if !videoDetail.tags.isEmpty {
                            Divider()
                            
                            Text("Tags")
                                .font(.headline)
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], alignment: .leading) {
                                ForEach(videoDetail.tags, id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        
                        // Open in YouTube Button
                        Button(action: openInYouTube) {
                            Label("Open in YouTube", systemImage: "play.rectangle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                    .padding(.horizontal)
                }
            } else if isLoading {
                ProgressView("Loading video details...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(
                    "Unable to load video",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Please try again later")
                )
            }
        }
        .toolbarTitleDisplayMode(.inline)
        .task {
            await loadVideoDetail()
        }
    }
    
    private func loadVideoDetail() async {
        do {
            let detail = try await channelStore.fetchVideoDetail(videoId: videoId)
            await MainActor.run {
                self.videoDetail = detail
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        }
    }
    
    private func openInYouTube() {
        let youtubeURL = URL(string: "https://www.youtube.com/watch?v=\(videoId)")!
        openURL(youtubeURL)
    }
}
