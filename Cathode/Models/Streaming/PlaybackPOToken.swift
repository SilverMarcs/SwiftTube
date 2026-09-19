import Foundation

nonisolated struct PlaybackPOToken: Sendable {
    let videoID: String
    let value: String
    let expiresAt: Date

    func applying(to url: URL) throws -> URL {
        guard url.scheme == "https", url.host()?.hasSuffix(".googlevideo.com") == true,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw PlaybackBrokerError.invalidResponse
        }
        var items = components.queryItems ?? []
        items.removeAll { $0.name == "pot" }
        items.append(URLQueryItem(name: "pot", value: value))
        components.queryItems = items
        guard let result = components.url else { throw PlaybackBrokerError.invalidResponse }
        return result
    }
}
