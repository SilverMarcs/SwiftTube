//
//  VideoLoader.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 28/09/2025.
//

import SwiftData
import Foundation

@ModelActor
actor VideoLoader {
    func loadAllChannelVideos() async {
        let channels = try! modelExecutor.modelContext.fetch(FetchDescriptor<Channel>())
        
        // First, fetch basic video data from RSS
        for channel in channels {
            do {
                let channelVideos = try await FeedParser.fetchChannelVideosFromRSS(channel: channel)
                for video in channelVideos {
                    upsertVideo(video)
                }
            } catch {
                print("Error fetching videos for \(channel.title): \(error)")
            }
        }
        
        try? modelExecutor.modelContext.save()
    }
    
    func refreshAllVideos() async {
        let channels = try! modelExecutor.modelContext.fetch(FetchDescriptor<Channel>())
        
        // Fetch fresh video data from RSS
        for channel in channels {
            do {
                let channelVideos = try await FeedParser.fetchChannelVideosFromRSS(channel: channel)
                for video in channelVideos {
                    upsertVideo(video)
                }
            } catch {
                print("Error fetching videos for \(channel.title): \(error)")
            }
        }
        
        try? modelExecutor.modelContext.save()
    }
    

    
    private func upsertVideo(_ video: Video) {
        let videoId = video.id
        
        if let existing = try? modelExecutor.modelContext.fetch(FetchDescriptor<Video>(predicate: #Predicate { $0.id == videoId })).first {
            // Only update basic fields from RSS feed, preserve rich data
            let hadRichData = existing.likeCount != nil
            existing.title = video.title
            existing.videoDescription = video.videoDescription
            existing.thumbnailURL = video.thumbnailURL
            existing.publishedAt = video.publishedAt
            existing.channelTitle = video.channelTitle
            existing.url = video.url
            existing.channel = video.channel
            // Preserve rich data fields: likeCount, viewCount, commentCount, duration, isShort
        } else {
            modelExecutor.modelContext.insert(video)
        }
    }
}
