//
//  VideoAPI.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 21/06/2025.
//

import Foundation

extension PipedAPI {
//    func fetchVideoDetails(videoId: String) async -> Video? {
//        guard let data = await makeUnauthenticatedRequest(to: "streams/\(videoId)") else { return nil }
//        
//        do {
//            let videoDetail = try JSONDecoder().decode(VideoDetailResponse.self, from: data)
//            return videoDetail.toVideo()
//        } catch {
//            return nil
//        }
//    }
    
//    func fetchTrending(region: String = "US") async -> [Video] {
//        guard let data = await makeUnauthenticatedRequest(to: "trending", parameters: ["region": region]) else { return [] }
//        
//        do {
//            let videos = try JSONDecoder().decode([Video].self, from: data)
//            return videos.compactMap { $0.toVideo() }
//        } catch {
//            return []
//        }
//    }
//    
//    func search(query: String, filter: String = "all") async -> [Video] {
//        guard let data = await makeUnauthenticatedRequest(to: "search", parameters: ["q": query, "filter": filter]) else { return [] }
//        
//        do {
//            let searchResponse = try JSONDecoder().decode(SearchResponse.self, from: data)
//            return searchResponse.items?.compactMap { $0.toVideo() } ?? []
//        } catch {
//            return []
//        }
//    }
    
    func fetchChannelDetails(channelId: String) async -> Channel? {
        guard let data = await makeUnauthenticatedRequest(to: "channel/\(channelId)") else { return nil }
        
        do {
            let channelResponse = try JSONDecoder().decode(ChannelResponse.self, from: data)
            return channelResponse.toChannel()
        } catch {
            return nil
        }
    }
    
    func fetchVideoDetail(videoId: String) async -> VideoDetailResponse? {
        guard let data = await makeUnauthenticatedRequest(to: "streams/\(videoId)") else {
            return nil
        }
        
        do {
            let video = try JSONDecoder().decode(VideoDetailResponse.self, from: data)
            return video
        } catch {
            print("Error decoding video detail: \(error.localizedDescription)")
            return nil
        }
    }
}
