// Channel.swift
import Foundation
import SwiftData

@Model
final class Channel {
    @Attribute(.unique) var id: String          // UC...
    var title: String
    var channelDescription: String
    var thumbnailURL: String
    var uploadsPlaylistId: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Video.channel) var videos: [Video] = []

    init(id: String, title: String, channelDescription: String, thumbnailURL: String, uploadsPlaylistId: String) {
        self.id = id
        self.title = title
        self.channelDescription = channelDescription
        self.thumbnailURL = thumbnailURL
        self.uploadsPlaylistId = uploadsPlaylistId
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}