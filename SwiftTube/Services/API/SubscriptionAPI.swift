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
    
    func fetchSubscribedFeed() async -> [Video] {
        guard let data = await makeAuthenticatedRequest(to: "feed", useQueryToken: true) else { return [] }
        
        do {
            let videoResponses = try JSONDecoder().decode([VideoResponse].self, from: data)
            return videoResponses.compactMap { $0.toVideo() }
        } catch {
            return []
        }
    }
}
