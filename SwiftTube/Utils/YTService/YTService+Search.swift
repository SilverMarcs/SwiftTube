import Foundation

extension YTService {
    static func search(query: String) async throws -> SearchResults {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = URL(string: "\(baseURL)/search?part=snippet&q=\(encoded)")!
        
        let response: SearchResponse = try await fetchResponse(from: url)
        
        var videos: [Video] = []
        var channels: [Channel] = []
        
        for item in response.items {
            if item.id.kind == "youtube#video", let videoId = item.id.videoId {
                let channel = Channel(
                    id: item.snippet.channelId,
                    title: item.snippet.channelTitle,
                    channelDescription: "",
                    thumbnailURL: YouTubeVideoThumbnail(videoID: videoId).url!.absoluteString,
                    viewCount: 0,
                    subscriberCount: 0
                )
                let video = Video(
                    id: videoId,
                    title: item.snippet.title,
                    videoDescription: item.snippet.description,
                    thumbnailURL: YouTubeVideoThumbnail(videoID: videoId).url!.absoluteString,
                    publishedAt: Date(),
                    url: "https://www.youtube.com/watch?v=\(videoId)",
                    channel: channel,
                    viewCount: "0",
                    isShort: false
                )
                videos.append(video)
            } else if item.id.kind == "youtube#channel", let channelId = item.id.channelId {
                let channel = Channel(
                    id: channelId,
                    title: item.snippet.title,
                    channelDescription: item.snippet.description,
                    thumbnailURL: item.snippet.thumbnails.high?.url ?? "",
                    viewCount: 0,
                    subscriberCount: 0
                )
                channels.append(channel)
            }
        }
        
        return SearchResults(videos: videos, channels: channels)
    }
}

struct SearchResults {
    let videos: [Video]
    let channels: [Channel]
}
