import Foundation

// MARK: - Video

/// Mirrors the Android `Video` data model.
public struct Video: Identifiable, Hashable, Codable, Sendable {
    public let id: String                   // videoId
    public var title: String
    public var channelTitle: String
    public var channelId: String?
    public var description: String?
    public var duration: TimeInterval?      // seconds
    public var viewCount: Int?
    public var publishedAt: Date?
    public var isLive: Bool
    public var isUpcoming: Bool
    public var isShort: Bool
    /// True only when the API response explicitly provided a portrait thumbnail
    /// (i.e. from reelItemRenderer). False for Shorts detected via other signals
    /// (ustreamerConfig, reelWatchEndpoint, etc.) whose portrait thumbnail slot
    /// on YouTube's CDN returns a blank black image rather than a real thumb.
    public var hasPortraitThumbnail: Bool
    public var watchProgress: Double?       // 0.0 – 1.0
    public var playlistId: String?
    public var playlistIndex: Int?
    public var badges: [String]
    // Feed feedback tokens (session-scoped, from InnerTube menuRenderer)
    public var notInterestedToken: String?  // "Not interested" — hide this video
    public var dontLikeToken: String?       // "Don't like this video"
    public var hideChannelToken: String?    // "Don't recommend channel"
    // MARK: DeArrow overrides (applied from VideoPreloadCache after cache consume)
    public var deArrowTitle: String?
    public var deArrowThumbnailTimestamp: Double?
    // MARK: Local playback (in-app downloads — never persisted to cache JSON)
    /// Transient local file URL set when playing a downloaded video.
    /// Excluded from `CodingKeys` — never persisted to JSON cache.
    public var localFileURL: URL? = nil
    /// `true` when this video refers to a local downloaded file rather than a remote stream.
    public var isDownloaded: Bool { localFileURL != nil }

    private enum CodingKeys: String, CodingKey {
        case id, title, channelTitle, channelId, description, duration
        case viewCount, publishedAt, isLive, isUpcoming, isShort, hasPortraitThumbnail
        case watchProgress, playlistId, playlistIndex, badges
        case notInterestedToken, dontLikeToken, hideChannelToken
        case deArrowTitle, deArrowThumbnailTimestamp
        // localFileURL intentionally omitted — runtime only, never persisted to cache JSON
    }

    public init(
        id: String,
        title: String,
        channelTitle: String,
        channelId: String? = nil,
        description: String? = nil,
        duration: TimeInterval? = nil,
        viewCount: Int? = nil,
        publishedAt: Date? = nil,
        isLive: Bool = false,
        isUpcoming: Bool = false,
        isShort: Bool = false,
        hasPortraitThumbnail: Bool = false,
        watchProgress: Double? = nil,
        playlistId: String? = nil,
        playlistIndex: Int? = nil,
        badges: [String] = [],
        notInterestedToken: String? = nil,
        dontLikeToken: String? = nil,
        hideChannelToken: String? = nil
    ) {
        self.id = id
        self.title = title
        self.channelTitle = channelTitle
        self.channelId = channelId
        self.description = description
        self.duration = duration
        self.viewCount = viewCount
        self.publishedAt = publishedAt
        self.isLive = isLive
        self.isUpcoming = isUpcoming
        self.isShort = isShort
        self.hasPortraitThumbnail = hasPortraitThumbnail
        self.watchProgress = watchProgress
        self.playlistId = playlistId
        self.playlistIndex = playlistIndex
        self.badges = badges
        self.notInterestedToken = notInterestedToken
        self.dontLikeToken = dontLikeToken
        self.hideChannelToken = hideChannelToken
    }
}

// MARK: - Chapter

/// A named time-range bookmark within a video.
/// Mirrors Android's Chapter data class in YouTubeMediaItem.
public struct Chapter: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public let title: String
    public let startTime: TimeInterval  // seconds from the start

    public init(title: String, startTime: TimeInterval) {
        self.id = UUID()
        self.title = title
        self.startTime = startTime
    }
}

// MARK: - Convenience helpers

public extension Video {
    /// Clean 16:9 (or 9:16 for Shorts with explicit portrait thumbnail) thumbnail URL
    /// derived from the videoId. We never trust InnerTube's thumbnail field directly —
    /// it often returns letterboxed 4:3 variants.
    var thumbnailURL: URL? {
        let resolution: YouTubeThumbnailResolution =
            (isShort && hasPortraitThumbnail) ? .shortsPortrait : .hd720
        return YouTubeVideoThumbnail(videoID: id, resolution: resolution).url
    }

    /// Canonical watch URL for sharing.
    var watchURL: URL? {
        URL(string: "https://www.youtube.com/watch?v=\(id)")
    }

    var formattedDuration: String {
        guard let duration else { return "" }
        return formatDuration(duration)
    }

    /// Formatted compact view count, e.g. "1.2M views". Empty when unavailable.
    var displayViewCount: String {
        guard let viewCount else { return "" }
        switch viewCount {
        case 0..<1_000:         return "\(viewCount) views"
        case 1_000..<1_000_000: return String(format: "%.1fK views", Double(viewCount) / 1_000)
        default:                return String(format: "%.1fM views", Double(viewCount) / 1_000_000)
        }
    }

    /// Medium-quality 16:9 thumbnail (320×180). Always available — last resort fallback.
    var mqThumbnailURL: URL? {
        URL(string: "https://i.ytimg.com/vi/\(id)/mqdefault.jpg")
    }

    /// Uploader-supplied custom thumbnail (≥1280×720, 16:9). May 404 if the uploader
    /// never set a custom thumbnail (older / auto-generated videos).
    var maxresThumbnailURL: URL? {
        URL(string: "https://i.ytimg.com/vi/\(id)/maxresdefault.jpg")
    }

    /// Ordered 16:9 fallbacks: hq720 → mqdefault.
    var thumbnailFallbackURLs: [URL] {
        [thumbnailURL, mqThumbnailURL].compactMap { $0 }
    }

    /// Portrait (9:16) thumbnail used for Shorts cards.
    /// YouTube generates `oardefault.jpg` (360×640) for every Short.
    var portraitThumbnailURL: URL? {
        URL(string: "https://i.ytimg.com/vi/\(id)/oardefault.jpg")
    }
}
