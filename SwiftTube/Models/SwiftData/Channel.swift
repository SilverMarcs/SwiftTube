// Channel.swift
import Foundation
import SwiftData

@Model
final class Channel {
    @Attribute(.unique) var id: String          // UC...
    var title: String
    var channelDescription: String
    var thumbnailURL: String
    var viewCount: UInt64
    var subscriberCount: UInt64

    @Relationship(deleteRule: .cascade, inverse: \Video.channel) var videos: [Video] = []

    init(id: String, title: String, channelDescription: String, thumbnailURL: String, viewCount: UInt64, subscriberCount: UInt64) {
        self.id = id
        self.title = title
        self.channelDescription = channelDescription
        self.thumbnailURL = thumbnailURL
        self.viewCount = viewCount
        self.subscriberCount = subscriberCount
    }
}


// Local subscription struct for display only
struct Subscription: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let thumbnailURL: String
    let channelId: String
}
