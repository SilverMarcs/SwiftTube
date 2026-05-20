import Foundation

// MARK: - TokenManager
//
// Actor that owns all Keychain storage for OAuth tokens.
//
// YTTVAuthManager creates and holds a TokenManager, reading initial token state
// via `initialSnapshot` (nonisolated — safe from synchronous init).
// Consumers that want to react to future token changes subscribe to `updates`.
//
// Conservative scope (task #62): YTTVAuthManager delegates Keychain I/O here but
// still maintains its own @Observable stored vars for UI binding. The
// AsyncStream is available for future consumer migration but not yet consumed
// by InnerTubeAPI / VideoPreloadCache.

public actor TokenManager {

    // MARK: - Types

    public enum Update: Sendable {
        case refreshed(token: String?, expiresAt: Date?)
        case signedOut
    }

    public struct Snapshot: Sendable {
        public let accessToken: String?
        public let refreshToken: String?
        public let tokenExpiry: Date?
        public let accountName: String?
        public let accountAvatarURL: URL?
    }

    // MARK: - State

    private var accessToken: String?
    private var refreshToken: String?
    private var tokenExpiry: Date?
    private var accountName: String?
    private var accountAvatarURL: URL?

    private let service: String

    // MARK: - Stream

    private var continuation: AsyncStream<Update>.Continuation?

    /// Subscribe to receive future token updates without polling YTTVAuthManager.
    /// `nonisolated let` — accessible without `await`, safe cross-actor.
    public nonisolated let updates: AsyncStream<Update>

    // MARK: - Initial snapshot

    /// Snapshot of Keychain values at init time.
    /// `nonisolated let` — YTTVAuthManager.init() reads this without `await`.
    public nonisolated let initialSnapshot: Snapshot

    // MARK: - Init

    public init(keychainService: String = "com.cathode.ytauth") {
        service = keychainService

        var cont: AsyncStream<Update>.Continuation!
        let stream = AsyncStream<Update> { cont = $0 }
        updates = stream
        continuation = cont

        let snap = Snapshot(
            accessToken:     Self.kcGet(service: keychainService, key: "cathode_yt_access_token"),
            refreshToken:    Self.kcGet(service: keychainService, key: "cathode_yt_refresh_token"),
            tokenExpiry: {
                guard let s = Self.kcGet(service: keychainService, key: "cathode_yt_token_expiry")
                else { return nil }
                return ISO8601DateFormatter().date(from: s)
            }(),
            accountName:     Self.kcGet(service: keychainService, key: "cathode_yt_account_name"),
            accountAvatarURL: Self.kcGet(service: keychainService, key: "cathode_yt_avatar_url")
                                .flatMap(URL.init(string:))
        )
        initialSnapshot  = snap
        accessToken      = snap.accessToken
        refreshToken     = snap.refreshToken
        tokenExpiry      = snap.tokenExpiry
        accountName      = snap.accountName
        accountAvatarURL = snap.accountAvatarURL
    }

    // MARK: - Reads

    public func currentAccessToken() -> String?  { accessToken }
    public func currentRefreshToken() -> String? { refreshToken }
    public func currentTokenExpiry() -> Date?    { tokenExpiry }
    public func currentAccountName() -> String?  { accountName }
    public func currentAvatarURL() -> URL?       { accountAvatarURL }
    public func isSignedIn() -> Bool             { accessToken != nil }

    // MARK: - Mutations

    public func setToken(
        access: String?,
        refresh: String?,
        expiry: Date?,
        accountName: String?,
        avatarURL: URL?
    ) {
        self.accessToken      = access
        self.refreshToken     = refresh
        self.tokenExpiry      = expiry
        self.accountName      = accountName
        self.accountAvatarURL = avatarURL
        persistToKeychain()
        continuation?.yield(.refreshed(token: access, expiresAt: expiry))
    }

    public func clearToken() {
        accessToken      = nil
        refreshToken     = nil
        tokenExpiry      = nil
        accountName      = nil
        accountAvatarURL = nil
        deleteFromKeychain()
        continuation?.yield(.signedOut)
    }

    // MARK: - Private Keychain I/O

    private func persistToKeychain() {
        let fmt = ISO8601DateFormatter()
        Self.kcSet(service: service, key: "cathode_yt_access_token",  value: accessToken)
        Self.kcSet(service: service, key: "cathode_yt_refresh_token", value: refreshToken)
        Self.kcSet(service: service, key: "cathode_yt_token_expiry",  value: tokenExpiry.map { fmt.string(from: $0) })
        Self.kcSet(service: service, key: "cathode_yt_account_name",  value: accountName)
        Self.kcSet(service: service, key: "cathode_yt_avatar_url",    value: accountAvatarURL?.absoluteString)
    }

    private func deleteFromKeychain() {
        for key in ["cathode_yt_access_token", "cathode_yt_refresh_token", "cathode_yt_token_expiry",
                    "cathode_yt_account_name", "cathode_yt_avatar_url"] {
            Self.kcDelete(service: service, key: key)
        }
    }

    // MARK: - Static (nonisolated) Keychain helpers
    // Static methods are nonisolated — safe to call from actor init.

    private static func kcGet(service: String, key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func kcSet(service: String, key: String, value: String?) {
        let deleteQuery: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        guard let value, let data = value.data(using: .utf8) else { return }
        let addQuery: [CFString: Any] = [
            kSecClass:          kSecClassGenericPassword,
            kSecAttrService:    service,
            kSecAttrAccount:    key,
            kSecValueData:      data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private static func kcDelete(service: String, key: String) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
