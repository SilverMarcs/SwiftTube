import AVFoundation
import Foundation
#if os(tvOS)
import AVKit
#endif

/// Builds `AVMetadataItem`s for `AVPlayerItem.externalMetadata` and
/// timed navigation marker groups (chapters + sponsor segments) for tvOS.
enum PlayerMetadataBuilder {

    // MARK: - External Metadata

    /// Mirrors FinStream's BaseItemDto+Metadata pattern: artwork first so the
    /// Info pane has its dominant image, then title/subtitle/description and
    /// supporting fields. Redundancy across common/quickTime/iTunes spaces is
    /// intentional — Now Playing strip, Info pane, and AirPlay receivers each
    /// read different keys.
    static func externalMetadata(for video: Video) async -> [AVMetadataItem] {
        var metadata: [AVMetadataItem] = []

        // Artwork — load first so it's the dominant image in the Info pane.
        if let data = await loadArtwork(from: video.thumbnailURL) {
            metadata.append(makeArtworkItem(data))
        }

        // Title
        metadata.append(makeItem(.commonIdentifierTitle, video.title))
        metadata.append(makeItem(.quickTimeMetadataTitle, video.title))

        // Subtitle (channel name)
        metadata.append(makeItem(.iTunesMetadataTrackSubTitle, video.channelTitle))
        metadata.append(makeItem(.commonIdentifierArtist, video.channelTitle))

        // Description — feed/list Video objects don't carry one. Fall back to
        // /player (same path VideoDetailView uses) so the Info pane has body text.
        if let description = await resolveDescription(for: video) {
            metadata.append(makeItem(.commonIdentifierDescription, description))
            metadata.append(makeItem(.quickTimeMetadataDescription, description))
            metadata.append(makeItem(.iTunesMetadataDescription, description))
        }

        // Upload date
        if let publishedAt = video.publishedAt {
            let iso = ISO8601DateFormatter().string(from: publishedAt)
            metadata.append(makeItem(.commonIdentifierCreationDate, iso))
            metadata.append(makeItem(.quickTimeMetadataCreationDate, iso))
            let yearFormatter = DateFormatter()
            yearFormatter.dateFormat = "yyyy"
            metadata.append(makeItem(.iTunesMetadataReleaseDate, yearFormatter.string(from: publishedAt)))
        }

        // Publisher → channel
        metadata.append(makeItem(.commonIdentifierPublisher, video.channelTitle))
        metadata.append(makeItem(.iTunesMetadataPublisher, video.channelTitle))

        // View count surfaces in the secondary info row.
        if let v = video.viewCount {
            let viewsText = "\(v.formatted(.number.notation(.compactName))) views"
            metadata.append(makeItem(.quickTimeMetadataInformation, viewsText))
            metadata.append(makeItem(.iTunesMetadataUserComment, viewsText))
        }

        return metadata
    }

    // MARK: - Navigation Markers (chapters + sponsor segments)

    #if os(tvOS)
    static func navigationMarkerGroups(
        chapters: [DescriptionChapter],
        sponsors: [SponsorSegment],
        totalDuration: Double?
    ) -> [AVNavigationMarkersGroup] {
        struct Marker { let title: String; let start: Double; let end: Double }
        var markers: [Marker] = []

        for (i, ch) in chapters.enumerated() {
            let end: Double = {
                if i + 1 < chapters.count { return chapters[i + 1].seconds }
                return totalDuration ?? (ch.seconds + 1)
            }()
            guard end > ch.seconds else { continue }
            markers.append(Marker(title: ch.title, start: ch.seconds, end: end))
        }

        for s in sponsors {
            markers.append(Marker(title: "Sponsor", start: s.start, end: s.end))
        }

        markers.sort { $0.start < $1.start }

        let timed = markers.map { m -> AVTimedMetadataGroup in
            let timeRange = CMTimeRangeFromTimeToTime(
                start: CMTime(seconds: m.start, preferredTimescale: 600),
                end: CMTime(seconds: m.end, preferredTimescale: 600)
            )
            return AVTimedMetadataGroup(items: [makeItem(.commonIdentifierTitle, m.title)], timeRange: timeRange)
        }

        guard !timed.isEmpty else { return [] }
        return [AVNavigationMarkersGroup(title: nil, timedNavigationMarkers: timed)]
    }
    #endif

    // MARK: - Private helpers

    private static func makeItem(_ identifier: AVMetadataIdentifier, _ value: String) -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = identifier
        item.value = value as NSString
        item.extendedLanguageTag = "und"
        return item.copy() as! AVMetadataItem
    }

    private static func makeArtworkItem(_ data: Data) -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = .commonIdentifierArtwork
        item.value = data as NSData
        item.extendedLanguageTag = "und"
        return item
    }

    private static func resolveDescription(for video: Video) async -> String? {
        if let local = video.description?.trimmingCharacters(in: .whitespacesAndNewlines),
           !local.isEmpty {
            return local
        }
        do {
            let info = try await InnerTubeAPI.shared.fetchPlayerInfo(videoId: video.id)
            let fetched = info.video.description?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (fetched?.isEmpty == false) ? fetched : nil
        } catch {
            print("PlayerMetadataBuilder description fetch failed: \(error)")
            return nil
        }
    }

    private static func loadArtwork(from url: URL?) async -> Data? {
        guard let url else { return nil }
        do {
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
            let (data, _) = try await URLSession.shared.data(for: request)
            return data
        } catch {
            print("PlayerMetadataBuilder artwork failed: \(error)")
            return nil
        }
    }
}
