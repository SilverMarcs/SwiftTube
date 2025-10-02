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
        
        guard let channels = try? modelExecutor.modelContext.fetch(FetchDescriptor<Channel>()) else {
            print("Error fetching channels")
            return
        }
        
        // Fetch all existing video IDs once for efficient duplicate checking
        let existingVideoIds = await fetchAllVideoIds()
        
        // Fetch basic video data from RSS (without max results limit)
        await withTaskGroup(of: Void.self) { group in
            for channel in channels {
                group.addTask {
                    do {
                        let rssVideoData = try await FeedParser.fetchChannelVideosFromRSS(channelId: channel.id)
                        let filteredData = await self.filterRSSVideoData(rssVideoData)
                        for data in filteredData {
                            // Only insert if this video doesn't already exist
                            if !existingVideoIds.contains(data.id) {
                                let video = Video(
                                    id: data.id,
                                    title: data.title,
                                    videoDescription: data.videoDescription,
                                    thumbnailURL: data.thumbnailURL,
                                    publishedAt: data.publishedAt,
                                    url: data.url,
                                    channel: channel,
                                    viewCount: data.viewCount,
                                    isShort: data.isShort
                                )
                                self.modelExecutor.modelContext.insert(video)
                            }
                        }
                    } catch {
                        print("Error fetching videos for \(channel.title): \(error)")
                    }
                }
            }
        }
        
        // Unconditionally refresh metadata for recent 50 videos
        var descriptor = FetchDescriptor<Video>(sortBy: [SortDescriptor(\.publishedAt, order: .reverse)])
        descriptor.fetchLimit = 50
        
        if let videos = try? modelExecutor.modelContext.fetch(descriptor) {
            do {
                try await YTService.fetchVideoDetails(for: videos)
            } catch {
                print("Error updating video rich data: \(error)")
            }
        }
        
        do {
            try modelExecutor.modelContext.save()
        } catch {
            print("Error saving video loader: \(error)")
        }
    }
    
    private func filterRSSVideoData(_ rssData: [RSSVideoData]) -> [RSSVideoData] {
        // Single-pass filtering: keep all shorts and recent regular videos
        return rssData.filter { data in
            data.isShort || data.publishedAt >= Self.oneWeekAgo
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
                print("Cleaned up \(count) regular videos older than 7 days")
            }
        } catch {
            print("Error cleaning up old videos: \(error)")
        }
        
        // Clean up excess Shorts: keep only the most recent 100
        var shortsDescriptor = FetchDescriptor<Video>(
            predicate: #Predicate<Video> { $0.isShort == true },
            sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
        )
        shortsDescriptor.fetchOffset = 100
        
        do {
            let excessShorts = try modelExecutor.modelContext.fetch(shortsDescriptor)
            if !excessShorts.isEmpty {
                for short in excessShorts {
                    modelExecutor.modelContext.delete(short)
                }
                print("Cleaned up \(excessShorts.count) excess Shorts, keeping the most recent 100")
            }
        } catch {
            print("Error cleaning up excess Shorts: \(error)")
        }
    }
    
    private func fetchAllVideoIds() async -> Set<String> {
        let descriptor = FetchDescriptor<Video>()
        guard let videos = try? modelExecutor.modelContext.fetch(descriptor) else {
            return []
        }
        return Set(videos.map { $0.id })
    }
}
