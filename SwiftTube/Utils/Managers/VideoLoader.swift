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
    static let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()

    func loadAllChannelVideos() async {
        // First, clean up old videos
        await cleanupOldVideos()
        
        let channels = try! modelExecutor.modelContext.fetch(FetchDescriptor<Channel>())
        
        // Fetch basic video data from RSS (without max results limit)
        await withTaskGroup(of: Void.self) { group in
            for channel in channels {
                group.addTask {
                    do {
                        let channelVideos = try await FeedParser.fetchChannelVideosFromRSS(channel: channel)
                        let filteredVideos = await self.filterVideosForChannel(channelVideos)
                        for video in filteredVideos {
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
                        let filteredVideos = await self.filterVideosForChannel(channelVideos)
                        for video in filteredVideos {
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
    
    private func filterVideosForChannel(_ videos: [Video]) -> [Video] {
        // Separate shorts and regular videos
        let shorts = videos.filter { $0.isShort }
        let regularVideos = videos.filter { !$0.isShort }
        
        // For shorts: keep all of them (no filtering)
        var result = shorts
        
        // For regular videos: only keep those published within the last 15 days
        let recentRegularVideos = regularVideos.filter { $0.publishedAt >= Self.oneWeekAgo }
        result.append(contentsOf: recentRegularVideos)
        
        return result
    }
    
    func checkAndUpdateVideoDurations() async {
        let descriptor = FetchDescriptor<Video>(sortBy: [SortDescriptor(\.publishedAt, order: .reverse)])
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
        let cutoffDate = Self.oneWeekAgo
        let descriptor = FetchDescriptor<Video>(predicate: #Predicate<Video> { video in
            video.publishedAt < cutoffDate && video.isShort == false
        })
        
        do {
            let oldVideos = try modelExecutor.modelContext.fetch(descriptor)
            let count = oldVideos.count
            
            for video in oldVideos {
                modelExecutor.modelContext.delete(video)
            }
            
            if count > 0 {
                print("Cleaned up \(count) regular videos older than 15 days")
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
            existing.isShort = video.isShort // Update isShort status
            // Preserve rich data fields: likeCount, viewCount, commentCount, duration, definition, caption, updatedAt
        } else {
            modelExecutor.modelContext.insert(video)
            print("Inserted new video: '\(video.title)' (Short: \(video.isShort))")
        }
    }
}
