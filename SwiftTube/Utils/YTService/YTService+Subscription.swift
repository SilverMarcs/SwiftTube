//
//  YTService+Subscription.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 28/09/2025.
//

import Foundation

extension YTService {
    static func fetchMySubscriptions() async throws -> [Subscription] {
        let url = URL(string: "\(baseURL)/subscriptions?part=snippet&mine=true&maxResults=50")!
        
        let response: SubscriptionListResponse = try await fetchOAuthResponse(from: url)
        
        var subscriptions: [Subscription] = []
        for item in response.items {
            let subscription = Subscription(
                id: item.id,
                title: item.snippet.title,
                description: item.snippet.description,
                thumbnailURL: item.snippet.thumbnails.medium.url,
                channelId: item.snippet.resourceId.channelId
            )
            subscriptions.append(subscription)
        }
        
        return subscriptions
    }
}