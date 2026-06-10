import Foundation

enum TopShelfDeepLinkAction: String {
    case play
    case open
}

struct TopShelfDeepLink {
    static let scheme = "swifttube"

    let action: TopShelfDeepLinkAction
    let itemID: String

    static func makeURL(action: TopShelfDeepLinkAction, itemID: String) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = action.rawValue
        components.path = "/\(itemID)"
        return components.url
    }

    static func parse(_ url: URL) -> TopShelfDeepLink? {
        guard url.scheme == scheme,
              let action = TopShelfDeepLinkAction(rawValue: url.host ?? "") else {
            return nil
        }

        let pathParts = url.pathComponents.dropFirst()
        guard let itemID = pathParts.first, !itemID.isEmpty else {
            return nil
        }

        return TopShelfDeepLink(action: action, itemID: itemID)
    }
}
