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
        
        // Then fetch rich data for videos without it
        await fetchRichDataIfNeeded()
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
        
        // Force fetch rich data for recent videos
        await fetchRichDataForced()
    }
    
    private func fetchRichDataIfNeeded() async {
        let videoFetchDescriptor = FetchDescriptor<Video>(
            sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
        )
        
        guard let videos = try? modelExecutor.modelContext.fetch(videoFetchDescriptor) else { return }
        
        // Get the 50 most recent videos
        let recent50Videos = Array(videos.prefix(50))
        
        // Check how many don't have rich metadata (likeCount is our indicator)
        let videosWithoutRichData = recent50Videos.filter { $0.likeCount == nil }
        
        // Only fetch if at least 5 recent videos don't have rich data
        if videosWithoutRichData.count >= 5 {
            await fetchRichVideoData(for: videosWithoutRichData)
        }
    }
    
    private func fetchRichDataForced() async {
        let videoFetchDescriptor = FetchDescriptor<Video>(
            sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
        )
        
        guard let videos = try? modelExecutor.modelContext.fetch(videoFetchDescriptor) else { return }
        
        // Get the 50 most recent videos without rich data
        let recent50Videos = Array(videos.prefix(50))
        let videosWithoutRichData = recent50Videos.filter { $0.likeCount == nil }
        
        if !videosWithoutRichData.isEmpty {
            await fetchRichVideoData(for: videosWithoutRichData)
        }
    }
    
    private func fetchRichVideoData(for videos: [Video]) async {
        guard !videos.isEmpty else { return }
        
        do {
            try await YTService.fetchVideoDetails(for: videos)
            try? modelExecutor.modelContext.save()
            print("Successfully fetched rich data for \(videos.count) videos")
        } catch {
            print("Error fetching video details: \(error)")
        }
    }
    
    private func upsertVideo(_ video: Video) {
        let videoId = video.id
        
        if let existing = try? modelExecutor.modelContext.fetch(FetchDescriptor<Video>(predicate: #Predicate { $0.id == videoId })).first {
            existing.title = video.title
            existing.videoDescription = video.videoDescription
            existing.thumbnailURL = video.thumbnailURL
            existing.publishedAt = video.publishedAt
            existing.channelTitle = video.channelTitle
            existing.url = video.url
            existing.channel = video.channel
        } else {
            modelExecutor.modelContext.insert(video)
        }
    }
}