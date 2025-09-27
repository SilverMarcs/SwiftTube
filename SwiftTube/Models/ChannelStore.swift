// ChannelStore.swift
import Foundation

@Observable
class ChannelStore {
    var channels: [Channel] = []
    var videos: [Video] = []
    var isLoading = false
    
    private let apiKey = "AIzaSyCrI9toXHrVQXmx1ZwKc9hkhTBZM94k-do" // Replace with your API key
    private let baseURL = "https://www.googleapis.com/youtube/v3"
    
    init() {
        loadChannels()
    }
    
    // MARK: - Persistence
    private func loadChannels() {
        if let data = UserDefaults.standard.data(forKey: "saved_channels"),
           let decoded = try? JSONDecoder().decode([Channel].self, from: data) {
            self.channels = decoded
        }
    }
    
    private func saveChannels() {
        if let encoded = try? JSONEncoder().encode(channels) {
            UserDefaults.standard.set(encoded, forKey: "saved_channels")
        }
    }
    
    // MARK: - API Calls
    func addChannel(channelId: String) async {
        guard !channels.contains(where: { $0.id == channelId }) else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let channel: Channel
            if channelId.hasPrefix("@") {
                channel = try await fetchChannelFromHandle(from: channelId)
            } else {
                channel = try await fetchChannelInfo(channelId: channelId)
            }
            await MainActor.run {
                channels.append(channel)
                saveChannels()
            }
        } catch {
            print("Error adding channel: \(error)")
        }
    }
    
    private func fetchChannelFromHandle(from handle: String) async throws -> Channel {
        let trimmed = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.hasPrefix("@") ? trimmed : "@\(trimmed)"
        guard let encoded = normalized.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw APIError.invalidResponse
        }
        let url = URL(string: "\(baseURL)/channels?part=snippet,contentDetails&forHandle=\(encoded)&key=\(apiKey)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let res = try JSONDecoder().decode(ChannelResponse.self, from: data)
        guard let item = res.items.first else {
            throw APIError.channelNotFound
        }
        return Channel(
            id: item.id,
            title: item.snippet.title,
            description: item.snippet.description,
            thumbnailURL: item.snippet.thumbnails.medium.url,
            uploadsPlaylistId: item.contentDetails.relatedPlaylists.uploads
        )
    }
    
    private func fetchChannelInfo(channelId: String) async throws -> Channel {
        let url = URL(string: "\(baseURL)/channels?part=snippet,contentDetails&id=\(channelId)&key=\(apiKey)")!
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(ChannelResponse.self, from: data)
        
        guard let item = response.items.first else {
            throw APIError.channelNotFound
        }
        
        return Channel(
            id: item.id,
            title: item.snippet.title,
            description: item.snippet.description,
            thumbnailURL: item.snippet.thumbnails.medium.url,
            uploadsPlaylistId: item.contentDetails.relatedPlaylists.uploads
        )
    }
    
    func fetchAllVideos() async {
        isLoading = true
        defer { isLoading = false }
        
        var allVideos: [Video] = []
        
        for channel in channels {
            do {
                let channelVideos = try await fetchChannelVideosFromRSS(channel: channel)
                allVideos.append(contentsOf: channelVideos)
            } catch {
                print("Error fetching videos for \(channel.title): \(error)")
            }
        }
        
        await MainActor.run {
            // Sort by publish date, most recent first
            self.videos = allVideos.sorted { $0.publishedAt > $1.publishedAt }
        }
    }
    
    private func fetchChannelVideosFromRSS(channel: Channel) async throws -> [Video] {
        let url = URL(string: "https://www.youtube.com/feeds/videos.xml?channel_id=\(channel.id)")!
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        let parser = FeedParser()
        parser.parse(data: data)
        
        guard let feed = parser.feed else {
            throw APIError.invalidResponse
        }
        
        return feed.entries.prefix(10).map { entry in
            Video(
                id: entry.mediaGroup.videoId,
                title: entry.title,
                description: entry.mediaGroup.description,
                thumbnailURL: entry.mediaGroup.thumbnail.url,
                publishedAt: entry.published,
                channelId: channel.id,
                channelTitle: entry.author.name,
                url: entry.link
            )
        }
    }
    
    @available(*, deprecated, renamed: "fetchChannelVideosFromRSS")
    private func fetchChannelVideos(uploadsPlaylistId: String, channelId: String) async throws -> [Video] {
        let url = URL(string: "\(baseURL)/playlistItems?part=snippet,contentDetails&playlistId=\(uploadsPlaylistId)&maxResults=10&key=\(apiKey)")!
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(PlaylistResponse.self, from: data)
        
        return response.items.map { item in
            Video(
                id: item.contentDetails.videoId,
                title: item.snippet.title,
                description: item.snippet.description,
                thumbnailURL: item.snippet.thumbnails.medium.url,
                publishedAt: ISO8601DateFormatter().date(from: item.contentDetails.videoPublishedAt) ?? Date(),
                channelId: channelId,
                channelTitle: item.snippet.channelTitle,
                url: "https://www.youtube.com/watch?v=\(item.contentDetails.videoId)"
            )
        }
    }
    
    func removeChannel(_ channel: Channel) {
        channels.removeAll { $0.id == channel.id }
        saveChannels()
        // Remove videos from this channel
        videos.removeAll { $0.channelId == channel.id }
    }

    func fetchVideoDetail(videoId: String) async throws -> VideoDetail {
        let url = URL(string: "\(baseURL)/videos?part=snippet,contentDetails,statistics,status&id=\(videoId)&key=\(apiKey)")!
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(VideoDetailResponse.self, from: data)
        
        guard let item = response.items.first else {
            throw APIError.invalidResponse
        }
        
        return VideoDetail(
            id: item.id,
            title: item.snippet.title,
            description: item.snippet.description,
            channelId: item.snippet.channelId,
            channelTitle: item.snippet.channelTitle,
            publishedAt: ISO8601DateFormatter().date(from: item.snippet.publishedAt) ?? Date(),
            thumbnailURL: item.snippet.thumbnails.high?.url ?? item.snippet.thumbnails.medium.url,
            duration: formatDuration(item.contentDetails.duration),
            viewCount: formatNumber(item.statistics.viewCount),
            likeCount: item.statistics.likeCount.map(formatNumber),
            commentCount: item.statistics.commentCount.map(formatNumber),
            tags: item.snippet.tags ?? [],
            categoryId: item.snippet.categoryId,
            definition: item.contentDetails.definition.uppercased(),
            caption: item.contentDetails.caption == "true",
            privacyStatus: item.status.privacyStatus,
            embeddable: item.status.embeddable
        )
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
