//
//  VideoLoader.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 28/09/2025.
//

import SwiftUI

@Observable
final class VideoLoader {

    private(set) var videos: [Video] = []
    private(set) var shortVideos: [Video] = []

    private(set) var isLoading: Bool = false
    private let userDefaults = CloudStoreManager.shared

    /// In-memory order for shorts (video IDs). Shuffled on first feed load of the
    /// process; subsequent reloads preserve this order so prefetched stream URLs
    /// stay aligned with what the user actually swipes through.
    private var shortsOrder: [String] = []
    
    func loadAllChannelVideos() async {
        let channels = userDefaults.savedChannels
        guard !channels.isEmpty else {
            videos = []
            shortVideos = []
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
        
        // Separate shorts and regular videos
        let shorts = aggregatedVideos.filter { $0.isShort }
        let regularVideos = aggregatedVideos.filter { !$0.isShort }
        
        // Sort by publish date (desc)
        let sortedVideos = regularVideos.sorted { $0.publishedAt > $1.publishedAt }
        
        withAnimation {
            self.videos = sortedVideos
        }
        self.shortVideos = applyStableShuffle(to: shorts)

        let videosForDetails = self.videos.prefix(50)
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
    }

    func getMostRecentHistoryVideo() -> Video? {
        userDefaults.historyVideos.first
    }

    private func applyStableShuffle(to shorts: [Video]) -> [Video] {
        if shortsOrder.isEmpty {
            let shuffled = shorts.shuffled()
            shortsOrder = shuffled.map(\.id)
            return shuffled
        }
        let rank = Dictionary(uniqueKeysWithValues: shortsOrder.enumerated().map { ($1, $0) })
        let known = shorts
            .filter { rank[$0.id] != nil }
            .sorted { rank[$0.id]! < rank[$1.id]! }
        let new = shorts.filter { rank[$0.id] == nil }.shuffled()
        let merged = known + new
        shortsOrder = merged.map(\.id)
        return merged
    }
}
