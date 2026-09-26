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
}
