// VideoDetailView.swift
import SwiftUI
import SwiftData

struct VideoDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let video: Video
    
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
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
                        Label(formatNumber(video.viewCount ?? "0") + " views", systemImage: "eye")
                        
                        if let likes = video.likeCount {
                            Label(formatNumber(likes), systemImage: "hand.thumbsup")
                        }
                        
                        if let comments = video.commentCount {
                            Label(formatNumber(comments), systemImage: "bubble.left")
                        }
                        
                        Spacer()
                        
                        Text(formatDurationFromSeconds(video.duration))
                            .font(.caption.monospaced())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.background.secondary)
                            .clipShape(.capsule)
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
                    Text(LocalizedStringKey("Description"))
                        .font(.headline)
                    
                    Text(video.videoDescription)
                        .font(.body)
                }
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
        try await YTService.fetchVideoDetails(for: video)
    }
    
    private func formatDurationFromSeconds(_ totalSeconds: Int?) -> String {
        guard let totalSeconds = totalSeconds else { return "" }
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
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
