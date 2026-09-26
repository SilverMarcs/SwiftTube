import Foundation

/// Small seam for exercising delayed iCloud delivery without a real account.
@MainActor
protocol YTCookieCloudStore {
    var dictionaryRepresentation: [String: Any] { get }
    func set(_ value: Any?, forKey key: String)
    func removeObject(forKey key: String)
    @discardableResult func synchronize() -> Bool
}

extension NSUbiquitousKeyValueStore: YTCookieCloudStore { }
