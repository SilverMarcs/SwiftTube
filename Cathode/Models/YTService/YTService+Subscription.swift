//
//  YTService+Subscription.swift
//  Cathode
//
//  InnerTube-backed subscriptions list. Requires an authenticated session
//  (TV OAuth via `YTTVAuthManager`). Throws if not signed in.
//

import Foundation

extension YTService {
    static func fetchMySubscriptions() async throws -> [Channel] {
        let channels = try await InnerTubeAPI.shared.fetchSubscribedChannels()
        return channels.map(Channel.init)
    }
}
