//
//  SubscriptionAPI.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 21/06/2025.
//

import Foundation

extension PipedAPI {
    private func manageSubscription(channelId: String, endpoint: String) async -> Bool {
        guard let body = try? JSONEncoder().encode(SubscriptionRequest(channelId: channelId)) else { return false }
        return await makeAuthenticatedRequest(to: endpoint, method: "POST", body: body) != nil
    }
    
    func subscribe(to channelId: String) async -> Bool {
        return await manageSubscription(channelId: channelId, endpoint: "subscribe")
    }
    
    func unsubscribe(from channelId: String) async -> Bool {
        return await manageSubscription(channelId: channelId, endpoint: "unsubscribe")
    }
    
    func fetchSubscriptions() async -> [Channel] {
        guard let data = await makeAuthenticatedRequest(to: "subscriptions") else { return [] }
        
        do {
            let channelResponses = try JSONDecoder().decode([ChannelResponse].self, from: data)
            return channelResponses.compactMap { $0.toChannel() }
        } catch {
            return []
        }
    }
    
    func fetchSubscribedFeed(page: Int? = nil) async -> [Video] {
        var parameters: [String: String] = [:]
        
        if let page = page {
            parameters["page"] = String(page)
        }
        
        guard let data = await makeAuthenticatedRequest(to: "feed", useQueryToken: true, parameters: parameters) else { return [] }
        
        do {
            let videos = try JSONDecoder().decode([Video].self, from: data)
            return videos.compactMap { $0 }
        } catch {
            print("Error decoding subscribed feed: \(error.localizedDescription)")
            return []
        }
    }
}
