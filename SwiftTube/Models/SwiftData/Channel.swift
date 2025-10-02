// Channel.swift
import Foundation
import SwiftData

protocol ChannelDisplayable {
    var id: String { get }
    var title: String { get }
    var thumbnailURL: String { get }
    var subtitle: String { get }
}

@Model
final class Channel {
    @Attribute(.unique) var id: String          // UC...
    var title: String
    var channelDescription: String
    var thumbnailURL: String
    var viewCount: UInt64
    var subscriberCount: UInt64

    init(id: String, title: String, channelDescription: String, thumbnailURL: String, viewCount: UInt64 = 0, subscriberCount: UInt64 = 0) {
        self.id = id
        self.title = title
        self.channelDescription = channelDescription
        self.thumbnailURL = thumbnailURL
        self.viewCount = viewCount
        self.subscriberCount = subscriberCount
    }
}

extension Channel: ChannelDisplayable {
    var subtitle: String {
        "\(Int(subscriberCount).formatNumber()) subscribers"
    }
}


// Local subscription struct for display only
struct Subscription: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let thumbnailURL: String
}

extension Subscription: ChannelDisplayable {
    var subtitle: String {
        description
    }
}
