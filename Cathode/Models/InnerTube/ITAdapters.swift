//
//  ITAdapters.swift
//  Cathode
//
//  Adapters bridging InnerTube models (ITVideo, ITChannel, ITComment)
//  into Cathode's existing top-level model shapes (Video, Channel, Comment).
//
//  Phase 2a: Used as the conversion layer so YTService internals can call
//  InnerTubeAPI without forcing call sites to change.
//

import Foundation

// MARK: - Channel

extension Channel {
    /// Map an InnerTube channel into Cathode's Channel shape.
    /// `subscriberCount`/`viewCount` are surfaced as 0 when not provided —
    /// the InnerTube `ITChannel.subscriberCount` is a free-form text string
    /// (e.g. "1.2M subscribers") rather than a numeric count.
    init(_ it: ITChannel) {
        let subs = Channel.parseAbbreviatedCount(it.subscriberCount)
        self.init(
            id: it.id,
            title: it.title,
            channelDescription: it.description ?? "",
            thumbnailURL: it.thumbnailURL?.absoluteString ?? "",
            viewCount: 0,
            subscriberCount: subs
        )
    }

    /// Parses YouTube's abbreviated subscriber strings ("1.2M", "532K", "1.4B subscribers")
    /// into a UInt64. Returns 0 if no number is recognised.
    static func parseAbbreviatedCount(_ text: String?) -> UInt64 {
        guard let text = text else { return 0 }
        // Strip everything except digits, decimal point and unit suffix letters.
        let scanner = Scanner(string: text)
        scanner.charactersToBeSkipped = .whitespacesAndNewlines
        var value: Double = 0
        guard scanner.scanDouble(&value) else { return 0 }
        // Look at the next non-space character to determine the multiplier.
        let remainder = text[scanner.currentIndex...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let multiplier: Double
        if remainder.hasPrefix("k") {
            multiplier = 1_000
        } else if remainder.hasPrefix("m") {
            multiplier = 1_000_000
        } else if remainder.hasPrefix("b") {
            multiplier = 1_000_000_000
        } else {
            multiplier = 1
        }
        return UInt64(value * multiplier)
    }
}

// MARK: - Video

extension Video {
    /// Map an InnerTube video into Cathode's Video shape.
    /// When ITVideo doesn't carry channel metadata (channelId missing), the
    /// channel field is filled with an empty stub so call sites don't crash.
    init(_ it: ITVideo) {
        let channel = Channel(
            id: it.channelId ?? "",
            title: it.channelTitle,
            channelDescription: "",
            thumbnailURL: "",
            viewCount: 0,
            subscriberCount: 0
        )
        self.init(it, channel: channel)
    }

    /// Map an ITVideo into Video, overriding the channel field with the
    /// caller-supplied `Channel` (used when we already have a saved Channel
    /// from disk that has full metadata, including avatar).
    init(_ it: ITVideo, channel: Channel) {
        let duration: Int? = it.duration.map { Int($0) }
        let isShort = it.isShort || (duration.map { $0 > 0 && $0 <= 60 } ?? false)
        // Always derive from videoId. The thumbnailURL returned by InnerTube often
        // resolves to hqdefault/sddefault (4:3 with black letterbox bars baked into
        // the JPEG). hq720 is a clean 16:9 variant available for every video; the
        // portrait `oardefault` is correct for Shorts whose response advertised one.
        let resolution: YouTubeThumbnailResolution =
            (isShort && it.hasPortraitThumbnail) ? .shortsPortrait : .hd720
        let thumbURL = YouTubeVideoThumbnail(videoID: it.id, resolution: resolution)
            .url?.absoluteString ?? ""
        let viewCount: String = it.viewCount.map(String.init) ?? "0"
        self.init(
            id: it.id,
            title: it.title,
            videoDescription: it.description ?? "",
            thumbnailURL: thumbURL,
            publishedAt: it.publishedAt ?? Date.distantPast,
            url: "https://www.youtube.com/watch?v=\(it.id)",
            channel: channel,
            viewCount: viewCount,
            isShort: isShort,
            likeCount: nil,
            duration: duration
        )
    }
}

// MARK: - Comment

extension Comment {
    /// Map a single ITComment top-level into Cathode's Comment.
    /// ITComment is flat (no nested replies). Reply expansion is not yet
    /// supported by the InnerTube layer, so `totalReplyCount` is left at 0
    /// and the `replies` array stays empty.
    init(_ it: ITComment) {
        let published = Comment.parseRelativeOrISODate(it.publishedTime) ?? Date()
        let likes = Int(it.likeCount.replacingOccurrences(of: ",", with: "")) ?? 0
        self.init(
            id: it.id,
            authorDisplayName: it.author,
            authorProfileImageUrl: it.authorAvatarURL?.absoluteString,
            authorChannelUrl: nil,
            authorChannelId: nil,
            textDisplay: it.text,
            textOriginal: it.text,
            likeCount: likes,
            publishedAt: published,
            updatedAt: nil,
            totalReplyCount: 0,
            isTopLevel: true,
            parentCommentId: nil
        )
    }

    /// Coarse parser for YouTube's "2 days ago" style strings.
    /// Returns nil if the input doesn't look like a relative-time string.
    private static func parseRelativeOrISODate(_ text: String) -> Date? {
        if let iso = ISO8601DateFormatter().date(from: text) { return iso }
        let lower = text.lowercased()
        let scanner = Scanner(string: lower)
        scanner.charactersToBeSkipped = .whitespacesAndNewlines
        var n: Int = 0
        guard scanner.scanInt(&n) else { return nil }
        let rest = lower[scanner.currentIndex...]
        let cal = Calendar.current
        let now = Date()
        if rest.contains("second") { return cal.date(byAdding: .second, value: -n, to: now) }
        if rest.contains("minute") { return cal.date(byAdding: .minute, value: -n, to: now) }
        if rest.contains("hour")   { return cal.date(byAdding: .hour,   value: -n, to: now) }
        if rest.contains("day")    { return cal.date(byAdding: .day,    value: -n, to: now) }
        if rest.contains("week")   { return cal.date(byAdding: .day,    value: -n * 7, to: now) }
        if rest.contains("month")  { return cal.date(byAdding: .month,  value: -n, to: now) }
        if rest.contains("year")   { return cal.date(byAdding: .year,   value: -n, to: now) }
        return nil
    }
}
