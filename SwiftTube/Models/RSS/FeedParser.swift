//
//  FeedParser.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 27/09/2025.
//

import Foundation

class FeedParser: NSObject, XMLParserDelegate {
    private static let isoFormatter = ISO8601DateFormatter()
    
    // Struct to hold temporary entry data with efficient string building
    private struct EntryBuilder {
        var titleChunks: [String] = []
        var link: String = ""
        var publishedChunks: [String] = []
        var updatedChunks: [String] = []
        var authorNameChunks: [String] = []
        var mediaTitleChunks: [String] = []
        var descriptionChunks: [String] = []
        var videoIdChunks: [String] = []
        var views: String? = nil
        
        mutating func reset() {
            titleChunks.removeAll(keepingCapacity: true)
            link = ""
            publishedChunks.removeAll(keepingCapacity: true)
            updatedChunks.removeAll(keepingCapacity: true)
            authorNameChunks.removeAll(keepingCapacity: true)
            mediaTitleChunks.removeAll(keepingCapacity: true)
            descriptionChunks.removeAll(keepingCapacity: true)
            videoIdChunks.removeAll(keepingCapacity: true)
            views = nil
        }
    }
    
    var feed: Feed?
    private var currentElement = ""
    private var entries: [Entry] = []
    private var feedTitleChunks: [String] = []
    private var inEntry = false
    private var currentEntryBuilder = EntryBuilder()

    func parse(data: Data) {
        // Preallocate with reasonable capacity
        entries.reserveCapacity(50)
        
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        if elementName == "entry" {
            inEntry = true
            currentEntryBuilder.reset()
        } else if elementName == "link" && inEntry {
            if let href = attributeDict["href"] {
                currentEntryBuilder.link = href
            }
        } else if elementName == "media:statistics" && inEntry {
            currentEntryBuilder.views = attributeDict["views"]
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        switch currentElement {
        case "title":
            if inEntry {
                currentEntryBuilder.titleChunks.append(trimmed)
            } else {
                feedTitleChunks.append(trimmed)
            }
        case "published":
            currentEntryBuilder.publishedChunks.append(trimmed)
        case "updated":
            currentEntryBuilder.updatedChunks.append(trimmed)
        case "name":
            currentEntryBuilder.authorNameChunks.append(trimmed)
        case "media:title":
            currentEntryBuilder.mediaTitleChunks.append(trimmed)
        case "media:description":
            currentEntryBuilder.descriptionChunks.append(trimmed)
        case "yt:videoId":
            currentEntryBuilder.videoIdChunks.append(trimmed)
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "entry" {
            inEntry = false
            
            // Join accumulated chunks once at the end
            let title = currentEntryBuilder.titleChunks.joined()
            let published = currentEntryBuilder.publishedChunks.joined()
            let updated = currentEntryBuilder.updatedChunks.joined()
            let authorName = currentEntryBuilder.authorNameChunks.joined()
            let mediaTitle = currentEntryBuilder.mediaTitleChunks.joined()
            let description = currentEntryBuilder.descriptionChunks.joined()
            let videoId = currentEntryBuilder.videoIdChunks.joined()
            
            let publishedDate = FeedParser.isoFormatter.date(from: published) ?? Date.distantPast
            let updatedDate = FeedParser.isoFormatter.date(from: updated) ?? Date.distantPast
            
            let author = Author(name: authorName)
            let videoThumbnail = YouTubeVideoThumbnail(videoID: videoId)
            let thumbnail = FeedThumbnail(url: videoThumbnail.url?.absoluteString ?? "", width: 120, height: 90)
            let mediaGroup = MediaGroup(title: mediaTitle, description: description, thumbnail: thumbnail, videoId: videoId, views: currentEntryBuilder.views)
            let entry = Entry(title: title, link: currentEntryBuilder.link, published: publishedDate, updated: updatedDate, author: author, mediaGroup: mediaGroup)
            entries.append(entry)
        }
    }

    func parserDidEndDocument(_ parser: XMLParser) {
        let feedTitle = feedTitleChunks.joined()
        feed = Feed(title: feedTitle, entries: entries)
    }
    
    static func fetchChannelVideosFromRSS(channelId: String) async throws -> [RSSVideoData] {
        let url = URL(string: "https://www.youtube.com/feeds/videos.xml?channel_id=\(channelId)")!
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        // Explicitly perform parsing on a background task to ensure it doesn't block
        return try await Task.detached(priority: .userInitiated) {
            let parser = await FeedParser()
            await parser.parse(data: data)
            
            guard let feed = await parser.feed else {
                throw APIError.invalidResponse
            }
            
            // Use map instead of compactMap since we're not filtering anything
            return feed.entries.map { entry in
                RSSVideoData(
                    id: entry.mediaGroup.videoId,
                    title: entry.title,
                    videoDescription: entry.mediaGroup.description,
                    thumbnailURL: entry.mediaGroup.thumbnail.url,
                    publishedAt: entry.published,
                    url: entry.link,
                    viewCount: entry.mediaGroup.views ?? "0",
                    isShort: entry.link.contains("/shorts/")
                )
            }
        }.value
    }
}
