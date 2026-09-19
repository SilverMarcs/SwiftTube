import Foundation

nonisolated struct PlaybackCloudConfiguration: Codable, Equatable, Sendable {
    var isUnlocked = false
    var isEnabled = false
    var serverURL = PlaybackBrokerClient.baseURLString
    var apiKey: String?
}
