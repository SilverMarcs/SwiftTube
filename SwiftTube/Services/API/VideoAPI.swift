//
//  VideoAPI.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 21/06/2025.
//

import Foundation

extension PipedAPI {    
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
    func search(query: String, filter: SearchFilter = .videos) async -> [SearchItem] {
        guard !query.isEmpty else { return [] }
        
        let parameters = [
            "q": query,
            "filter": filter.rawValue
        ]
        
        guard let data = await makeUnauthenticatedRequest(to: "search", parameters: parameters) else { 
            return [] 
        }
        
        do {
            let searchResponse = try JSONDecoder().decode(SearchResponse.self, from: data)
            return searchResponse.items?.compactMap { $0.toSearchItem() } ?? []
        } catch {
            print("Error decoding search results: \(error.localizedDescription)")
            return []
        }
    }
    
    func fetchChannelDetails(channelId: String) async -> Channel? {
        guard let data = await makeUnauthenticatedRequest(to: "channel/\(channelId)") else { return nil }
        
        do {
            let channelResponse = try JSONDecoder().decode(ChannelResponse.self, from: data)
            return channelResponse.toChannel()
        } catch {
            return nil
        }
    }
    
    func fetchVideoDetail(videoId: String) async -> VideoDetail? {
        guard let data = await makeUnauthenticatedRequest(to: "streams/\(videoId)") else {
            return nil
        }
        
        do {
            let video = try JSONDecoder().decode(VideoDetail.self, from: data)
            return video
        } catch {
            print("Error decoding video detail: \(error.localizedDescription)")
            return nil
        }
    }
    
    func fetchComments(videoId: String) async -> CommentsData? {
        guard let data = await makeUnauthenticatedRequest(to: "comments/\(videoId)") else {
            return nil
        }
        
        do {
            let commentsResponse = try JSONDecoder().decode(CommentsResponse.self, from: data)
            return commentsResponse.toCommentsData()
        } catch {
            print("Error decoding comments: \(error.localizedDescription)")
            return nil
        }
    }
}
