//
//  YTService+Subscription.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 28/09/2025.
//

import Foundation

extension YTService {
    static func fetchMySubscriptions() async throws -> [Channel] {
        var allSubscriptions: [Channel] = []
        var nextPageToken: String? = nil
        
        repeat {
            var urlString = "\(baseURL)/subscriptions?part=snippet&mine=true&maxResults=50"
            if let token = nextPageToken {
                urlString += "&pageToken=\(token)"
            }
            
            let url = URL(string: urlString)!
            let response: SubscriptionListResponse = try await fetchResponse(from: url, forceOAuth: true)
            
            for item in response.items {
                let subscription = Channel(
                    id: item.snippet.resourceId.channelId,
                    title: item.snippet.title,
                    channelDescription: item.snippet.description,
                    thumbnailURL: item.snippet.thumbnails.medium.url
                )
                allSubscriptions.append(subscription)
            }
            
            nextPageToken = response.nextPageToken
        } while nextPageToken != nil
        
        return allSubscriptions
    }
}
