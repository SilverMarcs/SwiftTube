// Channel.swift
import Foundation

struct Channel: Codable, Identifiable, Hashable {
    var id: String          // UC...
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

extension Channel {
    var subtitle: String {
        subscriberCount == 0 ? channelDescription : "\(Int(subscriberCount).formatNumber()) subscribers"
    }
}
