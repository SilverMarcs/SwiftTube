import TVServices

final class ContentProvider: TVTopShelfContentProvider {

    override func loadTopShelfContent() async -> (any TVTopShelfContent)? {
        let cachedItems = TopShelfCache.load()
        let items = cachedItems.compactMap { snapshot -> TVTopShelfCarouselItem? in
            let item = TVTopShelfCarouselItem(identifier: snapshot.id)
            item.title = snapshot.title
            item.summary = snapshot.summary
            item.genre = snapshot.genre
            item.creationDate = snapshot.creationDate
            if let duration = snapshot.durationSeconds {
                item.duration = duration
            }

            if let playURL = TopShelfDeepLink.makeURL(action: .play, itemID: snapshot.id) {
                item.playAction = TVTopShelfAction(url: playURL)
            }

            if let openURL = TopShelfDeepLink.makeURL(action: .open, itemID: snapshot.id) {
                item.displayAction = TVTopShelfAction(url: openURL)
            }

            item.namedAttributes = makeAttributes(for: snapshot)
            item.setImageURL(snapshot.imageURL, for: .screenScale1x)
            item.setImageURL(snapshot.imageURL, for: .screenScale2x)
            return item
        }

        guard !items.isEmpty else {
            return nil
        }

        return TVTopShelfCarouselContent(style: .details, items: items)
    }

    private func makeAttributes(for snapshot: TopShelfItemSnapshot) -> [TVTopShelfNamedAttribute] {
        var attributes: [TVTopShelfNamedAttribute] = []

        if let channel = snapshot.channelTitle, !channel.isEmpty {
            attributes.append(TVTopShelfNamedAttribute(name: "Channel", values: [channel]))
        }

        if let views = snapshot.viewCount {
            let value: String
            switch views {
            case 0..<1_000:         value = "\(views)"
            case 1_000..<1_000_000: value = String(format: "%.1fK", Double(views) / 1_000)
            default:                value = String(format: "%.1fM", Double(views) / 1_000_000)
            }
            attributes.append(TVTopShelfNamedAttribute(name: "Views", values: [value]))
        }

        if let creationDate = snapshot.creationDate {
            let value = creationDate.formatted(.dateTime.year())
            attributes.append(TVTopShelfNamedAttribute(name: "Year", values: [value]))
        }

        return attributes
    }
}
