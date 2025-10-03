//
//  VideoLoader.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 28/09/2025.
//

import Foundation

@Observable
final class VideoLoader {
    public var videos: [Video] = []
    private(set) var isLoading: Bool = false
    private let userDefaults = UserDefaultsManager.shared
    
    func loadAllChannelVideos() async {        
        let channels = userDefaults.savedChannels
        guard !channels.isEmpty else {
            videos = []
            return
        }
        
        // Build locally to avoid partial UI updates
        let aggregatedVideos: [Video] = await withTaskGroup(of: [Video].self, returning: [Video].self) { group in
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
            
            var all: [Video] = []
            for await channelVideos in group {
                all.append(contentsOf: channelVideos)
            }
            return all
        }
        
        // Sort locally
        let sorted = aggregatedVideos.sorted { $0.publishedAt > $1.publishedAt }
        
        // Only now populate the observable array (one atomic update)
        self.videos = sorted
        
        // #if !DEBUG
        // Fetch details for the first 50 non-short videos
        let videosForDetails = self.videos.filter { !$0.isShort }.prefix(50)
        if !videosForDetails.isEmpty {
            do {
                var mutableVideos = Array(videosForDetails)
                try await YTService.fetchVideoDetails(for: &mutableVideos)
                
                // Update the corresponding entries in self.videos
                let lookup = Dictionary(uniqueKeysWithValues: mutableVideos.map { ($0.id, $0) })
                for i in self.videos.indices {
                    if let updated = lookup[self.videos[i].id] {
                        self.videos[i] = updated
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
