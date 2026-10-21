import Foundation

/// One page of videos returned by a browse or search request.
public struct VideoGroup: Identifiable, Sendable {
    public let id: UUID
    public var title: String?
    public var videos: [Video]
    public var nextPageToken: String?

    public init(id: UUID = UUID(), title: String? = nil, videos: [Video] = [], nextPageToken: String? = nil) {
        self.id = id
        self.title = title
        self.videos = videos
        self.nextPageToken = nextPageToken
    }
}

// MARK: - Channel

public struct Channel: Identifiable, Hashable, Codable, Sendable {
    public let id: String   // channelId (UC…)
    public var title: String
    public var handle: String?  // @handle — feed video tiles often use this as their channelId reference
    public var description: String?
    public var thumbnailURL: URL?
    public var subscriberCount: String?
    public var isSubscribed: Bool

    public init(
        id: String,
        title: String,
        handle: String? = nil,
        description: String? = nil,
        thumbnailURL: URL? = nil,
        subscriberCount: String? = nil,
        isSubscribed: Bool = false
    ) {
        self.id = id
        self.title = title
        self.handle = handle
        self.description = description
        self.thumbnailURL = thumbnailURL
        self.subscriberCount = subscriberCount
        self.isSubscribed = isSubscribed
    }
}

// MARK: - PlaylistInfo

public struct PlaylistInfo: Identifiable, Codable, Sendable {
    public let id: String
    public var title: String
    public var videoCount: Int?
    public var thumbnailURL: URL?

    public init(id: String, title: String, videoCount: Int? = nil, thumbnailURL: URL? = nil) {
        self.id = id
        self.title = title
        self.videoCount = videoCount
        self.thumbnailURL = thumbnailURL
    }
}

// MARK: - ITSponsorSegment

/// A SponsorBlock segment within a video.
public struct ITSponsorSegment: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var start: TimeInterval
    public var end: TimeInterval
    public var category: Category

    public enum Category: String, Codable, CaseIterable, Sendable {
        case sponsor       = "sponsor"
        case selfPromo     = "selfpromo"
        case interaction   = "interaction"
        case intro         = "intro"
        case outro         = "outro"
        case preview       = "preview"
        case filler        = "filler"
        case musicOfftopic = "music_offtopic"
        case poiHighlight  = "poi_highlight"
    }

    public init(id: UUID = UUID(), start: TimeInterval, end: TimeInterval, category: Category) {
        self.id = id
        self.start = start
        self.end = end
        self.category = category
    }
}
