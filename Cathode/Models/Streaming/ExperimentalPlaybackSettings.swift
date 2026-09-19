import Foundation
import Observation

@MainActor
@Observable
final class ExperimentalPlaybackSettings {
    static let shared = ExperimentalPlaybackSettings()
    static let cloudKey = "playbackBroker.configuration.v1"

    private var configuration = PlaybackCloudConfiguration()
    var apiKey: String { configuration.apiKey ?? "" }
    var isUnlocked: Bool { configuration.isUnlocked }
    var serverURL: String { configuration.serverURL }
    var isServerPlaybackEnabled: Bool {
        get { configuration.isEnabled }
        set { configuration.isEnabled = newValue; publish() }
    }
    // Missing credentials fail in the broker instead of silently selecting local extraction.
    var usesBroker: Bool { isUnlocked && isServerPlaybackEnabled }

    @ObservationIgnored private let cloud = NSUbiquitousKeyValueStore.default
    @ObservationIgnored private var unlockPressCount = 0

    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(cloudChanged(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: NSUbiquitousKeyValueStore.default)
        refreshFromCloud()
    }

    @objc private nonisolated func cloudChanged(_ notification: Notification) {
        Task { @MainActor [weak self] in self?.refreshFromCloud() }
    }

    private func refreshFromCloud() {
        cloud.synchronize()
        configuration = cloud.data(forKey: Self.cloudKey)
            .flatMap { try? JSONDecoder().decode(PlaybackCloudConfiguration.self, from: $0) }
            ?? PlaybackCloudConfiguration()
    }

    func saveConnection(serverURL: String, apiKey: String) throws {
        let address = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: address), PlaybackBrokerClient.isAllowedServerURL(url),
              !key.isEmpty, !key.contains(where: { $0.isNewline }), key.utf8.count <= 512 else {
            throw PlaybackBrokerError.invalidConfiguration
        }
        configuration.serverURL = address
        configuration.apiKey = key
        publish()
    }

    func registerUnlockPress() {
        guard !isUnlocked else { return }
        unlockPressCount += 1
        guard unlockPressCount >= 7 else { return }
        configuration.isUnlocked = true
        publish()
        resetUnlockProgress()
    }

    func resetUnlockProgress() { unlockPressCount = 0 }

    private func publish() {
        if let data = try? JSONEncoder().encode(configuration) { cloud.set(data, forKey: Self.cloudKey) }
        cloud.synchronize()
    }
}
