import Foundation

extension InnerTubeAPI {
    /// Searches only the supplied creator/menu commands, never related videos.
    /// Ignore playlist and feed browse IDs when finding the channel action.
    func channelBrowseID(in value: Any?, depth: Int = 0) -> String? {
        guard depth < 30 else { return nil }
        if let dictionary = value as? [String: Any] {
            if let endpoint = dictionary["browseEndpoint"] as? [String: Any],
               let id = endpoint["browseId"] as? String,
               (id.hasPrefix("UC") && id.count > 2) || (id.hasPrefix("@") && id.count > 1) {
                return id
            }
            if let metadata = dictionary["webCommandMetadata"] as? [String: Any],
               let path = metadata["url"] as? String,
               let components = URLComponents(string: path),
               components.host == nil || ["youtube.com", "www.youtube.com"].contains(components.host?.lowercased()),
               components.scheme == nil || components.scheme == "https" {
                let parts = components.path.split(separator: "/")
                if parts.count == 1, let handle = parts.first, handle.hasPrefix("@"), handle.count > 1 {
                    return String(handle)
                }
                if parts.count == 2, parts[0] == "channel", parts[1].hasPrefix("UC"), parts[1].count > 2 {
                    return String(parts[1])
                }
            }
            for key in dictionary.keys.sorted() {
                if let id = channelBrowseID(in: dictionary[key], depth: depth + 1) {
                    return id
                }
            }
        } else if let array = value as? [Any] {
            for item in array {
                if let id = channelBrowseID(in: item, depth: depth + 1) {
                    return id
                }
            }
        }
        return nil
    }

    /// Read only explicit creator images, never a video's content thumbnail.
    func channelAvatarURL(in value: Any?, depth: Int = 0) -> URL? {
        guard depth < 30 else { return nil }
        if let dictionary = value as? [String: Any] {
            let avatar = dictionary["avatarViewModel"] as? [String: Any]
            let image = avatar?["image"] as? [String: Any]
            let thumbnail = dictionary["channelThumbnailWithLinkRenderer"] as? [String: Any]
                ?? dictionary["channelThumbnailRenderer"] as? [String: Any]
            let legacyImage = thumbnail?["thumbnail"] as? [String: Any]
                ?? dictionary["avatar"] as? [String: Any]
            let sources = image?["sources"] as? [[String: Any]]
                ?? image?["thumbnails"] as? [[String: Any]]
                ?? legacyImage?["thumbnails"] as? [[String: Any]]
            if let url = sources?.reversed().compactMap({ source -> URL? in
                guard let text = source["url"] as? String,
                      let url = normalizeThumbURL(text),
                      ["https", "http"].contains(url.scheme), url.host != nil else { return nil }
                return url
            }).first {
                return url
            }
            for key in dictionary.keys.sorted() {
                if let url = channelAvatarURL(in: dictionary[key], depth: depth + 1) { return url }
            }
        } else if let array = value as? [Any] {
            for item in array {
                if let url = channelAvatarURL(in: item, depth: depth + 1) { return url }
            }
        }
        return nil
    }
}
