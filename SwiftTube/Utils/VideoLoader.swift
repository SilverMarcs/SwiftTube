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
    static let oneMonthAgo =  Calendar.current.date(byAdding: .day, value: -15, to: Date()) ?? Date()

    func loadAllChannelVideos() async {
        // First, clean up videos older than a month
        await cleanupOldVideos()
        
        let channels = try! modelExecutor.modelContext.fetch(FetchDescriptor<Channel>())
        
        // Fetch basic video data from RSS (without max results limit)
        await withTaskGroup(of: Void.self) { group in
            for channel in channels {
                group.addTask {
                    do {
                        let channelVideos = try await FeedParser.fetchChannelVideosFromRSS(channel: channel)
                        let recentVideos = channelVideos.filter { $0.publishedAt >= Self.oneMonthAgo }
                        for video in recentVideos {
                            await self.upsertVideo(video)
                        }
                    } catch {
                        print("Error fetching videos for \(channel.title): \(error)")
                    }
                }
            }
        }
        
        await checkAndUpdateVideoDurations()
        
        try? modelExecutor.modelContext.save()
    }
    
    func refreshAllVideos() async {
        let channels = try! modelExecutor.modelContext.fetch(FetchDescriptor<Channel>())
        
        // Fetch fresh video data from RSS
        await withTaskGroup(of: Void.self) { group in
            for channel in channels {
                group.addTask {
                    do {
                        let channelVideos = try await FeedParser.fetchChannelVideosFromRSS(channel: channel)
                        let recentVideos = channelVideos.filter { $0.publishedAt >= Self.oneMonthAgo }
                        for video in recentVideos {
                            await self.upsertVideo(video)
                        }
                    } catch {
                        print("Error fetching videos for \(channel.title): \(error)")
                    }
                }
            }
        }
        
        try? modelExecutor.modelContext.save()
    }
    
    func checkAndUpdateVideoDurations() async {
        var descriptor = FetchDescriptor<Video>(sortBy: [SortDescriptor(\.publishedAt, order: .reverse)])
        // descriptor.fetchLimit = 5
        let videos = try! modelExecutor.modelContext.fetch(descriptor)
        
        let top5 = Array(videos.prefix(5))
        let allMissingRichData = top5.allSatisfy { video in
            (video.duration == nil || video.duration == 0) && video.likeCount == nil
        }
        
        if allMissingRichData {
            let latest50 = Array(videos.prefix(50))
            do {
                try await YTService.fetchVideoDetails(for: latest50)
                print("Updated rich data for latest 50 videos")
            } catch {
                print("Error updating video rich data: \(error)")
            }
        } else {
            print("Top 5 videos already have rich data set")
        }
    }
    
    private func cleanupOldVideos() async {
        let cutoffDate = Self.oneMonthAgo
        let descriptor = FetchDescriptor<Video>(predicate: #Predicate<Video> { video in
            video.publishedAt < cutoffDate
        })
        
        do {
            let oldVideos = try modelExecutor.modelContext.fetch(descriptor)
            let count = oldVideos.count
            
            for video in oldVideos {
                modelExecutor.modelContext.delete(video)
            }
            
            if count > 0 {
                print("Cleaned up \(count) videos older than a month")
            }
        } catch {
            print("Error cleaning up old videos: \(error)")
        }
    }
    
    private func upsertVideo(_ video: Video) {
        let videoId = video.id
        
        if let existing = try? modelExecutor.modelContext.fetch(FetchDescriptor<Video>(predicate: #Predicate { $0.id == videoId })).first {
            // Only update basic fields from RSS feed, preserve rich data
            existing.title = video.title
            existing.videoDescription = video.videoDescription
            existing.thumbnailURL = video.thumbnailURL
            existing.publishedAt = video.publishedAt
            existing.url = video.url
            existing.channel = video.channel
            // Preserve rich data fields: likeCount, viewCount, commentCount, duration, definition, caption, updatedAt, isShort
        } else {
            modelExecutor.modelContext.insert(video)
            print("Inserted new video: '\(video.title)'")
        }
    }
}
