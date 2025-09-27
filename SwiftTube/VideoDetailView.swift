// VideoDetailView.swift
import SwiftUI
import SwiftData

struct VideoDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let video: Video
    
    @State private var isLoading = false
    
    private let apiKey = "AIzaSyCrI9toXHrVQXmx1ZwKc9hkhTBZM94k-do" // Replace with your API key
    private let baseURL = "https://www.googleapis.com/youtube/v3"
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Thumbnail
                AsyncImage(url: URL(string: video.thumbnailURL)) { image in
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
                    Text(video.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    // Channel & Date
                    HStack {
                        Text(video.channelTitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Text(video.publishedAt, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Stats Row
                    HStack {
                        Label(formatNumber(String(video.viewCount ?? 0)) + " views", systemImage: "eye")
                        
                        if let likes = video.likeCount {
                            Label(formatNumber(String(likes)), systemImage: "hand.thumbsup")
                        }
                        
                        if let comments = video.commentCount {
                            Label(formatNumber(String(comments)), systemImage: "bubble.left")
                        }
                        
                        Spacer()
                        
                        Text(video.duration ?? "")
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
                        Text(video.definition ?? "")
                        
                        if video.caption ?? false {
                            Text("CC")
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    
                    Divider()
                    
                    // Description
                    Text("Description")
                        .font(.headline)
                    
                    Text(video.videoDescription)
                        .font(.body)
                }
                .padding(.horizontal)
            }
            .overlay {
                if isLoading {
                   UniversalProgressView()
                }
            }
        }
        .toolbarTitleDisplayMode(.inline)
        // .task {
        //     await loadVideoDetail()
        // }
    }
    
    private func loadVideoDetail() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await fetchVideoDetail(for: video)
            try? modelContext.save()
        } catch {
            print(error.localizedDescription)
        }
    }
    
    private func fetchVideoDetail(for video: Video) async throws {
        let url = URL(string: "\(baseURL)/videos?part=snippet,contentDetails,statistics&id=\(video.id)&key=\(apiKey)")!
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(VideoDetailResponse.self, from: data)
        
        guard let item = response.items.first else {
            throw APIError.invalidResponse
        }
        
        // Update the video with details
        video.duration = formatDuration(item.contentDetails.duration)
        video.viewCount = Int(item.statistics.viewCount)
        video.likeCount = item.statistics.likeCount.flatMap(Int.init)
        video.commentCount = item.statistics.commentCount.flatMap(Int.init)
        video.definition = item.contentDetails.definition.uppercased()
        video.caption = item.contentDetails.caption == "true"
        video.updatedAt = Date()
    }
    
    private func formatDuration(_ isoDuration: String) -> String {
        // Convert PT4M13S to "4:13"
        let pattern = "PT(?:(\\d+)H)?(?:(\\d+)M)?(?:(\\d+)S)?"
        let regex = try! NSRegularExpression(pattern: pattern)
        let matches = regex.firstMatch(in: isoDuration, range: NSRange(isoDuration.startIndex..., in: isoDuration))
        
        let hours = matches?.range(at: 1).location != NSNotFound ? 
            Int(String(isoDuration[Range(matches!.range(at: 1), in: isoDuration)!])) ?? 0 : 0
        let minutes = matches?.range(at: 2).location != NSNotFound ? 
            Int(String(isoDuration[Range(matches!.range(at: 2), in: isoDuration)!])) ?? 0 : 0
        let seconds = matches?.range(at: 3).location != NSNotFound ? 
            Int(String(isoDuration[Range(matches!.range(at: 3), in: isoDuration)!])) ?? 0 : 0
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    private func formatNumber(_ numberString: String) -> String {
        guard let number = Int(numberString) else { return numberString }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000)
        } else if number >= 1_000 {
            return String(format: "%.1fK", Double(number) / 1_000)
        } else {
            return formatter.string(from: NSNumber(value: number)) ?? numberString
        }
    }
}
