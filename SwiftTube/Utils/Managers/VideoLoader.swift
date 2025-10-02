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
        
        // Fetch basic video data from RSS (without max results limit)
        await withTaskGroup(of: Void.self) { group in
            for channel in channels {
                group.addTask {
                    do {
                        let rssVideoData = try await FeedParser.fetchChannelVideosFromRSS(channelId: channel.id)
                        let filteredData = await self.filterRSSVideoData(rssVideoData)
                        for data in filteredData {
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
                    } catch {
                        print("Error fetching videos for \(channel.title): \(error)")
                    }
                }
            }
        }
        
        // Unconditionally refresh metadata for recent 50 videos
        var descriptor = FetchDescriptor<Video>(sortBy: [SortDescriptor(\.publishedAt, order: .reverse)])
        descriptor.fetchLimit = 50
        
        #if !DEBUG // dont fetch details on debug due to many app launches
        if let videos = try? modelExecutor.modelContext.fetch(descriptor) {
            do {
                try await YTService.fetchVideoDetails(for: videos)
                print("Fetched details for \(videos.count) videos")
            } catch {
                print("Error updating video rich data: \(error)")
            }
        }
        #endif
        
        do {
            try modelExecutor.modelContext.save()
        } catch {
            print("Error saving video loader: \(error)")
        }
    }
    
    private func filterRSSVideoData(_ rssData: [RSSVideoData]) -> [RSSVideoData] {
        // Keep only videos from the last 7 days
        return rssData.filter { data in
            data.publishedAt >= Self.oneWeekAgo
        }
    }
    
    private func cleanupOldVideos() async {
        let cutoffDate = Self.oneWeekAgo
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
                print("Cleaned up \(count) videos older than 7 days")
            }
        } catch {
            print("Error cleaning up old videos: \(error)")
        }
    }
}
