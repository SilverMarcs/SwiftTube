//
//  VideoLoader.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 28/09/2025.
//

import Foundation

// TODO: probably dotesnt need to be in the env

@Observable
final class VideoLoader {
    var videos: [Video] = []
    private let userDefaults = UserDefaultsManager.shared
    
    func loadAllChannelVideos() async {
        let channels = userDefaults.savedChannels
        guard !channels.isEmpty else {
            videos = []
            return
        }
        
        videos = []
        
        // Fetch videos from RSS for all channels
        await withTaskGroup(of: [Video].self) { group in
            for channel in channels {
                group.addTask {
                    do {
                        return try await FeedParser.fetchChannelVideosFromRSS(channel: channel)
                    } catch {
                        print("Error fetching videos for \(channel.title): \(error)")
                        return []
                    }
                }
            }
            for await channelVideos in group {
                videos.append(contentsOf: channelVideos)
            }
        }
        
        // Sort by published date
        videos.sort { $0.publishedAt > $1.publishedAt }
        
        // #if !DEBUG
        // Fetch details for the first 50 non-short videos
        let videosForDetails = videos.filter { !$0.isShort }.prefix(50)
        if !videosForDetails.isEmpty {
            do {
                var mutableVideos = Array(videosForDetails)
                try await YTService.fetchVideoDetails(for: &mutableVideos)
                
                // Update the videos in the main array
                for updatedVideo in mutableVideos {
                    if let index = videos.firstIndex(where: { $0.id == updatedVideo.id }) {
                        videos[index] = updatedVideo
                    }
                }
                print("Fetched details for \(mutableVideos.count) videos")
            } catch {
                print("Error updating video rich data: \(error)")
            }
        }
        // #endif
    }
    
    func getMostRecentHistoryVideo() -> Video? {
        let historyVideos = videos.filter { userDefaults.isInHistory($0.id) }
            .sorted {
                let time1 = userDefaults.getWatchTime($0.id) ?? .distantPast
                let time2 = userDefaults.getWatchTime($1.id) ?? .distantPast
                return time1 > time2
            }
        return historyVideos.first
    }
}
