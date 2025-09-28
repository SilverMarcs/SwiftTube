//
//  FeedParser.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 27/09/2025.
//

import Foundation

class FeedParser: NSObject, XMLParserDelegate {
    var feed: Feed?
    private var currentElement = ""
    private var currentEntry: Entry?
    private var entries: [Entry] = []
    private var feedTitle = ""
    private var inEntry = false
    private var currentTitle = ""
    private var currentLink = ""
    private var currentPublished = ""
    private var currentUpdated = ""
    private var currentAuthorName = ""
    private var currentMediaTitle = ""
    private var currentDescription = ""
    private var currentVideoId = ""

    func parse(data: Data) {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        if elementName == "entry" {
            inEntry = true
            currentEntry = nil
            currentTitle = ""
            currentLink = ""
            currentPublished = ""
            currentUpdated = ""
            currentAuthorName = ""
            currentMediaTitle = ""
            currentDescription = ""
            currentVideoId = ""
        } else if elementName == "link" && inEntry {
            if let href = attributeDict["href"] {
                currentLink = href
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            switch currentElement {
            case "title":
                if inEntry {
                    currentTitle += trimmed
                } else {
                    feedTitle += trimmed
                }
            case "published":
                currentPublished += trimmed
            case "updated":
                currentUpdated += trimmed
            case "name":
                currentAuthorName += trimmed
            case "media:title":
                currentMediaTitle += trimmed
            case "media:description":
                currentDescription += trimmed
            case "yt:videoId":
                currentVideoId += trimmed
            default:
                break
            }
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "entry" {
            inEntry = false
            if let publishedDate = ISO8601DateFormatter().date(from: currentPublished),
               let updatedDate = ISO8601DateFormatter().date(from: currentUpdated) {
                let author = Author(name: currentAuthorName)
                let videoThumbnail = YouTubeVideoThumbnail(videoID: currentVideoId)
                let thumbnail = FeedThumbnail(url: videoThumbnail.url?.absoluteString ?? "", width: 120, height: 90)
                let mediaGroup = MediaGroup(title: currentMediaTitle, description: currentDescription, thumbnail: thumbnail, videoId: currentVideoId)
                let entry = Entry(title: currentTitle, link: currentLink, published: publishedDate, updated: updatedDate, author: author, mediaGroup: mediaGroup)
                entries.append(entry)
            }
        }
    }

    func parserDidEndDocument(_ parser: XMLParser) {
        feed = Feed(title: feedTitle, entries: entries)
    }
    
    static func fetchChannelVideosFromRSS(channel: Channel) async throws -> [Video] {
        let url = URL(string: "https://www.youtube.com/feeds/videos.xml?channel_id=\(channel.id)")!
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        let parser = FeedParser()
        parser.parse(data: data)
        
        guard let feed = parser.feed else {
            throw APIError.invalidResponse
        }
        
        return feed.entries.prefix(10).map { entry in
            Video(
                id: entry.mediaGroup.videoId,
                title: entry.title,
                videoDescription: entry.mediaGroup.description,
                thumbnailURL: entry.mediaGroup.thumbnail.url,
                publishedAt: entry.published,
                channelTitle: entry.author.name,
                url: entry.link,
                channel: channel
            )
        }
    }
}
