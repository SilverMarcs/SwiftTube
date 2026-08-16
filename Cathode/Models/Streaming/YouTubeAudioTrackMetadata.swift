import Foundation

nonisolated struct YouTubeAudioTrackMetadata: Sendable {
    let id: String
    let displayName: String
    let isDefault: Bool
    let isAutoDubbed: Bool

    var primaryLanguageCode: String? {
        guard let languageTag = id.split(separator: ".").first,
              let primaryCode = languageTag.split(separator: "-").first
        else { return nil }
        return primaryCode.lowercased()
    }

    var isOriginal: Bool {
        displayName.localizedStandardContains("original")
    }
}
