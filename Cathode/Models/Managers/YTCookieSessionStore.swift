import Foundation

@MainActor
final class YTCookieSessionStore {
    nonisolated static let prefix = "cathode_yt_session_v2."
    private static let localKey = "youtube-history-session-v2"
    private static let legacyKey = "cathode_yt_cookie_jar"
    private let cloud: any YTCookieCloudStore
    private let writerID: String

    init(cloud: any YTCookieCloudStore = NSUbiquitousKeyValueStore.default, writerID: String? = nil) {
        self.cloud = cloud
        let key = "youtube-history-writer-id"
        if let writerID {
            self.writerID = writerID
        } else if let existing = UserDefaults.standard.string(forKey: key) {
            self.writerID = existing
        } else {
            self.writerID = UUID().uuidString
            UserDefaults.standard.set(self.writerID, forKey: key)
        }
        cloud.synchronize()
    }

    func loadLocal() -> YTCookieSession? {
        guard let text = KeychainManager.shared.load(key: Self.localKey),
              let data = Data(base64Encoded: text) else { return nil }
        return try? JSONDecoder().decode(YTCookieSession.self, from: data)
    }

    func saveLocal(_ session: YTCookieSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        KeychainManager.shared.save(key: Self.localKey, data: data.base64EncodedString())
    }

    func latest() -> YTCookieSession? {
        records().map(\.session).max { $1.isNewer(than: $0) }
    }

    func synchronize() { cloud.synchronize() }

    /// Each login and device has its own slot. KVS has no compare-and-swap:
    /// separate slots prevent offline old devices (and older app versions using
    /// the legacy key) from overwriting a newer login before learning about it.
    func publish(_ session: YTCookieSession) {
        if let latest = latest(), latest.isNewer(than: session) { return }
        guard let data = try? JSONEncoder().encode(session) else { return }
        cloud.set(data, forKey: Self.prefix + session.id.uuidString + "." + writerID)
        // Bound storage while keeping multiple generations for delayed devices.
        let all = records()
        let retained = Set(all.map(\.session).sorted { $0.isNewer(than: $1) }
            .reduce(into: [UUID]()) { ids, record in
                if ids.count < 3 && !ids.contains(record.id) { ids.append(record.id) }
            })
        for record in all where !retained.contains(record.session.id) {
            cloud.removeObject(forKey: record.key)
        }
        cloud.synchronize()
    }

    /// Read-only migration. Old cookies are never published just by launching.
    func legacyCookies() -> [YTStoredCookie] {
        guard let data = cloud.dictionaryRepresentation[Self.legacyKey] as? Data else { return [] }
        return (try? JSONDecoder().decode([YTStoredCookie].self, from: data)) ?? []
    }

    private func records() -> [(key: String, session: YTCookieSession)] {
        cloud.dictionaryRepresentation.compactMap { key, value in
            guard key.hasPrefix(Self.prefix), let data = value as? Data,
                  let session = try? JSONDecoder().decode(YTCookieSession.self, from: data) else { return nil }
            return (key, session)
        }
    }
}
