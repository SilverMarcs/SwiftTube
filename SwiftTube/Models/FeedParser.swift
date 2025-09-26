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
    private var currentThumbnailUrl = ""
    private var currentThumbnailWidth = ""
    private var currentThumbnailHeight = ""
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
            currentThumbnailUrl = ""
            currentThumbnailWidth = ""
            currentThumbnailHeight = ""
            currentVideoId = ""
        } else if elementName == "link" && inEntry {
            if let href = attributeDict["href"] {
                currentLink = href
            }
        } else if elementName == "media:thumbnail" && inEntry {
            if let url = attributeDict["url"], let width = attributeDict["width"], let height = attributeDict["height"] {
                currentThumbnailUrl = url
                currentThumbnailWidth = width
                currentThumbnailHeight = height
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
               let updatedDate = ISO8601DateFormatter().date(from: currentUpdated),
               let width = Int(currentThumbnailWidth),
               let height = Int(currentThumbnailHeight) {
                let author = Author(name: currentAuthorName)
                let thumbnail = Thumbnail(url: currentThumbnailUrl, width: width, height: height)
                let mediaGroup = MediaGroup(title: currentMediaTitle, description: currentDescription, thumbnail: thumbnail, videoId: currentVideoId)
                let entry = Entry(title: currentTitle, link: currentLink, published: publishedDate, updated: updatedDate, author: author, mediaGroup: mediaGroup)
                entries.append(entry)
            }
        }
    }

    func parserDidEndDocument(_ parser: XMLParser) {
        feed = Feed(title: feedTitle, entries: entries)
    }
}