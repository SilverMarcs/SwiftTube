import Foundation

/// Home pagination loads more shelves; each shelf has its own item continuation.
struct HomeFeedPage: Sendable {
    var shelves: [VideoGroup]
    var nextPageToken: String?
}
