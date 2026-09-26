import CryptoKit
import Foundation
import SwiftUI
#if canImport(WebKit)
import WebKit
#endif

/// Owns the history session. Reading/importing never publishes credentials.
/// Only a verified login or a server-issued renewal can write to iCloud.
@MainActor
@Observable
public final class YTCookieAuth {
    public static let shared = YTCookieAuth()

    public private(set) var isSignedIn = false
    private(set) var historySyncStatus: WatchHistorySyncStatus = .unverified
    public private(set) var lastSyncedAt: Date?
    public private(set) var iCloudSyncedAt: Date?
    public private(set) var hydratedFromICloud = false
    private(set) var sapisid: String?
    private(set) var authCookies: [HTTPCookie] = []

    private let store = YTCookieSessionStore()
    private var current: YTCookieSession?
    private var bootstrapTask: Task<Void, Never>?
    private var validationTask: Task<Void, Never>?
    private var lastValidationAttempt: Date?
    private var lastRecoveryAttempt: Date?
    private var interactiveSignIn = false
#if canImport(WebKit)
    let dataStore = WKWebsiteDataStore.default()
    private let browser = YTSessionWebRefresher(dataStore: .default())
#endif

    private init() {
        current = store.loadLocal()
        updateState()
        NotificationCenter.default.addObserver(
            self, selector: #selector(externalKVSChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default
        )
        bootstrapTask = Task {
            await bootstrap()
        }
    }

    @objc private nonisolated func externalKVSChange(_ note: Notification) {
        let keys = note.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []
        guard keys.contains(where: { $0.hasPrefix(YTCookieSessionStore.prefix) || $0 == "cathode_yt_cookie_jar" }) else { return }
        Task { @MainActor in
            await refreshSignInState()
            await validateAndRenew()
        }
    }

    private func bootstrap() async {
        adoptLatestSession()
        if current == nil {
            var cookies = store.legacyCookies().compactMap(\.httpCookie)
#if canImport(WebKit)
            // The browser primes WebKit's persistent store. This is migration
            // only; once versioned, native state no longer rereads stale WebKit.
            if cookies.isEmpty {
                _ = await dataStore.httpCookieStore.allCookies()
                cookies = await dataStore.httpCookieStore.allCookies()
            }
#endif
            // Recheck after the suspension: a new login or iCloud delivery wins.
            adoptLatestSession()
            if current == nil && !cookies.isEmpty {
                let legacy = YTCookieSession(cookies: YTCookieSession.normalized(cookies), now: .distantPast)
                install(legacy, fromCloud: false)
            }
        }
        clearLegacySharedCookies()
    }

    /// Reconcile the local snapshot with iCloud. This method never uploads.
    public func refreshSignInState() async {
        await bootstrapTask?.value
        // Legacy KVS/WebKit data can arrive after the first launch read. Once a
        // versioned session exists, it remains authoritative.
        if current == nil && !interactiveSignIn { await bootstrap() }
        adoptLatestSession()
        updateState()
    }

    private func adoptLatestSession() {
        guard let remote = store.latest(), current.map({ remote.isNewer(than: $0) }) ?? true else { return }
        install(remote, fromCloud: true)
        iCloudSyncedAt = Date()
    }

    private func install(_ session: YTCookieSession, fromCloud: Bool) {
        current = session
        store.saveLocal(session)
        hydratedFromICloud = fromCloud
        historySyncStatus = .unverified
        lastValidationAttempt = nil
        updateState()
    }

    private func updateState() {
        authCookies = current?.signedOut == false
            ? current?.cookies.filter { $0.isValid(at: Date()) }.compactMap(\.httpCookie) ?? [] : []
        // The Google-domain SAPISID is not the signing cookie for youtube.com.
        sapisid = authCookies.first { $0.name == "SAPISID" && isYouTubeHost($0.domain) }?.value
            ?? authCookies.first { $0.name == "__Secure-3PAPISID" && isYouTubeHost($0.domain) }?.value
        isSignedIn = sapisid != nil
    }

    /// Bounded, coalesced health check. WebKit also runs YouTube's own browser
    /// renewal on supported platforms; tvOS renews from HTTP response cookies.
    func validateAndRenew(force: Bool = false) async {
        await refreshSignInState()
        guard !interactiveSignIn, let current, !current.signedOut else { return }
        if let validationTask { await validationTask.value; return }
        let interval: TimeInterval = historySyncStatus == .authenticated ? 6 * 60 * 60 : 60
        if !force, let lastValidationAttempt, Date().timeIntervalSince(lastValidationAttempt) < interval { return }
        store.synchronize()
        adoptLatestSession()
        lastValidationAttempt = Date()
        let task = Task {
            // If iCloud replaces the session during the check, validate the
            // replacement once rather than leaving its status unverified.
            for _ in 0..<2 {
                let revision = self.current?.revision
                await self.validateCurrentSession()
                if self.historySyncStatus != .unverified || self.current?.revision == revision { break }
            }
        }
        validationTask = task
        await task.value
        validationTask = nil
        if historySyncStatus != .unverified { lastValidationAttempt = Date() }
    }

    /// One silent recovery per minute after an explicit signed-out response.
    /// Reporting retries otherwise just reread the same rejected credentials.
    func recoverSession() async {
        store.synchronize()
        await refreshSignInState()
        if let lastRecoveryAttempt, Date().timeIntervalSince(lastRecoveryAttempt) < 60 { return }
        lastRecoveryAttempt = Date()
        await validateAndRenew(force: true)
    }

    private func validateCurrentSession() async {
        guard let snapshot = current else { return }
        do {
            var cookies = snapshot.cookies
#if canImport(WebKit)
            // Do not run a hidden browser alongside the user's login flow.
            if !interactiveSignIn {
                await replaceBrowserCookies(with: cookies)
                guard self.current?.acceptsResponse(to: snapshot) == true else { return }
                // A network failure in WebKit can still be recoverable natively.
                if (try? await browser.refresh()) != nil {
                    cookies = YTCookieSession.normalized(await dataStore.httpCookieStore.allCookies())
                }
            }
#endif
            let result = try await verify(cookies: cookies)
            adoptLatestSession()
            guard current?.acceptsResponse(to: snapshot) == true else { return }
            guard let authenticated = YTSessionValidation.authenticated(in: result.data) else {
                historySyncStatus = .unavailable
                return
            }
            if authenticated {
                acceptCookies(result.cookies, for: snapshot, verified: true)
                historySyncStatus = .authenticated
                lastSyncedAt = Date()
            } else {
                // Reconciliation above happens before declaring failure, so a
                // newer iCloud login is never marked failed by an older request.
                historySyncStatus = .needsSignIn
            }
        } catch {
            guard current?.acceptsResponse(to: snapshot) == true else { return }
            historySyncStatus = .unavailable
        }
    }

    private func verify(cookies: [YTStoredCookie]) async throws -> YTSessionTransport.Response {
        guard let url = URL(string: "https://www.youtube.com/feed/history") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.setValue(InnerTubeClients.WebSafari.userAgent, forHTTPHeaderField: "User-Agent")
        let result = try await YTSessionTransport.send(request, cookies: cookies)
        guard (200..<300).contains(result.http.statusCode) else { throw URLError(.badServerResponse) }
        return result
    }

    /// Account requests renew only their own snapshot, never a replacement login.
    func sendAuthenticated(_ request: URLRequest, sessionID: UUID? = nil) async throws -> YTSessionTransport.Response {
        await refreshSignInState()
        guard let snapshot = current, !snapshot.signedOut, isSignedIn else { throw URLError(.userAuthenticationRequired) }
        if let sessionID, sessionID != snapshot.id { throw CancellationError() }
        var request = request
        if request.value(forHTTPHeaderField: "Authorization") != nil {
            request.setValue(sapisidHashAuthorization(), forHTTPHeaderField: "Authorization")
        }
        var result = try await YTSessionTransport.send(request, cookies: snapshot.cookies)
        adoptLatestSession()
        guard current?.acceptsResponse(to: snapshot) == true else { throw CancellationError() }
        if (200..<300).contains(result.http.statusCode),
           YTSessionValidation.authenticated(in: result.data) != false {
            acceptCookies(result.cookies, for: snapshot)
        }
        result.sessionID = snapshot.id
        return result
    }

    private func acceptCookies(_ cookies: [YTStoredCookie], for snapshot: YTCookieSession, verified: Bool = false) {
        guard var session = current, session.acceptsResponse(to: snapshot) else { return }
        let shouldPublish = session.receive(cookies, verified: verified)
        if session != current {
            current = session
            store.saveLocal(session)
            updateState()
        }
        // Renewal retains the original generation date. Simply validating saved
        // cookies, including legacy cookies on launch, never causes an upload.
        if shouldPublish {
            store.publish(session)
        }
    }

#if canImport(WebKit)
    func prepareInteractiveSignIn() async {
        await refreshSignInState()
        interactiveSignIn = true
        await validationTask?.value
        await replaceBrowserCookies(with: current?.signedOut == false ? current?.cookies ?? [] : [])
    }

    func endInteractiveSignIn() { interactiveSignIn = false }

    /// Called after YouTube navigation finishes, not when a partial Google
    /// cookie set first appears. Only successful native verification publishes.
    func completeInteractiveSignIn() async -> Bool {
        guard interactiveSignIn else { return false }
        let cookies = YTCookieSession.normalized(await dataStore.httpCookieStore.allCookies())
        guard cookies.contains(where: { $0.name == "SAPISID" && isYouTubeHost($0.domain) }) else { return false }
        guard let result = try? await verify(cookies: cookies),
              YTSessionValidation.authenticated(in: result.data) == true,
              interactiveSignIn else { return false }
        adoptLatestSession()
        let session = YTCookieSession(cookies: result.cookies, after: current, verified: true)
        install(session, fromCloud: false)
        store.publish(session)
        historySyncStatus = .authenticated
        lastSyncedAt = Date()
        lastValidationAttempt = Date()
        interactiveSignIn = false
        return true
    }

    private func replaceBrowserCookies(with cookies: [YTStoredCookie]) async {
        let jar = dataStore.httpCookieStore
        for cookie in await jar.allCookies() where Self.isYouTubeCookie(cookie) {
            await jar.deleteCookie(cookie)
        }
        for cookie in cookies where cookie.isValid(at: Date()) {
            if let value = cookie.httpCookie { await jar.setCookie(value) }
        }
    }
#endif

    public func signOut() async {
        await refreshSignInState()
        // A new empty generation prevents delayed renewals from resurrecting it.
        let signedOut = YTCookieSession(cookies: [], after: current, signedOut: true)
        install(signedOut, fromCloud: false)
        store.publish(signedOut)
        clearLegacySharedCookies()
#if canImport(WebKit)
        await validationTask?.value
        if current?.id == signedOut.id && !interactiveSignIn {
            await replaceBrowserCookies(with: [])
        }
#endif
    }

    func setHistorySyncStatus(_ status: WatchHistorySyncStatus, for sessionID: UUID? = nil) {
        if let sessionID, current?.id != sessionID { return }
        historySyncStatus = status
    }

    func isCurrentSession(_ sessionID: UUID?) -> Bool {
        sessionID != nil && current?.id == sessionID && current?.signedOut == false
    }

    public func sapisidHashAuthorization(origin: String = "https://www.youtube.com") -> String? {
        guard let sapisid else { return nil }
        let timestamp = Int(Date().timeIntervalSince1970)
        let hash = Insecure.SHA1.hash(data: Data("\(timestamp) \(sapisid) \(origin)".utf8))
        let hex = hash.map { String(format: "%02x", $0) }.joined()
        return "SAPISIDHASH \(timestamp)_\(hex)"
    }

    public func cookieHeader(for url: URL) -> String? {
        let cookies = current?.cookies.filter { $0.matches(url) } ?? []
        guard !cookies.isEmpty, current?.signedOut == false else { return nil }
        return cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
    }

    nonisolated static func isYouTubeCookie(_ cookie: HTTPCookie) -> Bool {
        YTStoredCookie.isYouTubeDomain(cookie.domain)
    }

    private func isYouTubeHost(_ domain: String) -> Bool {
        let host = domain.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return host == "youtube.com" || host.hasSuffix(".youtube.com")
    }

    private func clearLegacySharedCookies() {
        for cookie in HTTPCookieStorage.shared.cookies ?? [] where Self.isYouTubeCookie(cookie) {
            HTTPCookieStorage.shared.deleteCookie(cookie)
        }
    }
}
