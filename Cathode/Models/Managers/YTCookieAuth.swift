//
//  YTCookieAuth.swift
//  Cathode
//
//  Cookie-based YouTube auth. Augments YTTVAuthManager (TV device-code OAuth).
//
//  Sign-in flow (iOS / macOS / visionOS): user authenticates inside a WKWebView
//  pointed at accounts.google.com → continues to youtube.com. The resulting
//  session cookies (SAPISID, __Secure-3PSID, HSID, SSID, APISID, LOGIN_INFO)
//  live in `WKWebsiteDataStore.default()`, which is also the data store used
//  by `YouTubePlayerKit` — so iframe playback automatically syncs watch
//  progress to YouTube's servers.
//
//  tvOS: no WebKit, so no interactive sign-in. Instead, the cookie set is
//  pulled from iCloud Keychain (written by an iOS device that did sign in)
//  and injected into `HTTPCookieStorage.shared` so URLSession-based InnerTube
//  calls and the SAPISIDHASH header can act on behalf of the account.
//
//  For native AVPlayer playback, we extract the `SAPISID` cookie, compute the
//  SAPISIDHASH header YouTube's web client uses, and attach it to authenticated
//  /player calls so we can get back account-bound watchtime tracking URLs.
//

import CryptoKit
import Foundation
import SwiftUI
#if canImport(WebKit)
import WebKit
#endif

@MainActor
@Observable
public final class YTCookieAuth {
    public static let shared = YTCookieAuth()

    public private(set) var isSignedIn: Bool = false
    public private(set) var lastSyncedAt: Date?

    /// Timestamp of the most recent successful read from / write to the iCloud
    /// KVS-backed cookie blob. Populated when we write the blob (iOS/mac/xrOS)
    /// or when we hydrate from it (any platform, including tvOS).
    public private(set) var iCloudSyncedAt: Date?

    /// True when the locally-active cookie set was hydrated from iCloud rather
    /// than captured from a sign-in on this device. Surfaced in Settings so
    /// the user knows watch-history sync is working through iCloud.
    public private(set) var hydratedFromICloud: Bool = false

    /// Current SAPISID cookie value — used to derive the SAPISIDHASH header.
    /// Refreshed every time `refreshSignInState()` runs.
    private(set) var sapisid: String?

    /// In-memory snapshot of the user's YouTube/Google auth cookies, refreshed
    /// on every `refreshSignInState()`. The watchtime/history path reads this
    /// instead of `HTTPCookieStorage.shared` because `StreamResolver`
    /// transiently strips that shared store to force anonymous extraction
    /// (ciphered `web` formats fail when login cookies ride along). Reading a
    /// private snapshot keeps account-bound tracking alive across that strip.
    private(set) var authCookies: [HTTPCookie] = []

#if canImport(WebKit)
    /// The default website data store. YouTubePlayerKit uses this same store
    /// when `useNonPersistentWebsiteDataStore` is `false` (its default).
    nonisolated let dataStore = WKWebsiteDataStore.default()

    /// Persistent WKWebView that exists only to wake the default data store
    /// on cold launch. Without any WKWebView instance bound to the data store,
    /// `httpCookieStore.allCookies()` returns an empty set even when valid
    /// session cookies are on disk — that's why a fresh app launch always
    /// showed "not signed in" until the user opened the sign-in sheet (which
    /// instantiated a WebView and woke the store as a side effect).
    private let dataStorePrimer: WKWebView
#endif

    private init() {
#if canImport(WebKit)
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        dataStorePrimer = WKWebView(frame: .zero, configuration: config)
#endif
        // Observe iCloud KVS pushes from sibling devices so cookie updates
        // written on iOS land here without a re-launch. FinStream uses the
        // same pattern for SeerrAuth and reports reliable tvOS sync.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(externalKVSChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default
        )
        NSUbiquitousKeyValueStore.default.synchronize()
        Task { await self.bootstrapSignInState() }
    }

    @objc private nonisolated func externalKVSChange(_ note: Notification) {
        Task { @MainActor in
            await self.hydrateFromICloud(force: true)
            await self.refreshSignInState()
        }
    }

#if canImport(WebKit)
    /// Forces the WKHTTPCookieStore to flush its disk read by chaining a
    /// `getAllCookies` callback before our state refresh. On a freshly
    /// primed data store the first call returns synchronously empty
    /// occasionally; this guards against that.
    private func bootstrapSignInState() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            dataStore.httpCookieStore.getAllCookies { _ in
                continuation.resume()
            }
        }
        await hydrateFromICloud(force: false)
        await refreshSignInState()
    }
#else
    /// tvOS bootstrap: no WebKit store, so iCloud KVS is the only cookie source.
    private func bootstrapSignInState() async {
        await hydrateFromICloud(force: false)
        await refreshSignInState()
    }
#endif

    /// Inject cookies from the iCloud KVS blob into the local cookie stores.
    /// `force == true` ignores the existing-SAPISID short-circuit, used when
    /// we know KVS just changed externally (sibling device pushed an update).
    private func hydrateFromICloud(force: Bool) async {
        let stored = Self.loadStoredCookies()
        guard !stored.isEmpty else {
            if force { hydratedFromICloud = false }
            return
        }
#if canImport(WebKit)
        let existing = await dataStore.httpCookieStore.allCookies()
        let alreadyHaveSession = existing.contains { $0.name == "SAPISID" && Self.isYouTubeCookie($0) }
#else
        let existing = HTTPCookieStorage.shared.cookies ?? []
        let alreadyHaveSession = existing.contains { $0.name == "SAPISID" && Self.isYouTubeCookie($0) }
#endif
        if alreadyHaveSession && !force { return }

        for cookie in stored.compactMap({ $0.httpCookie }) {
            HTTPCookieStorage.shared.setCookie(cookie)
#if canImport(WebKit)
            await dataStore.httpCookieStore.setCookie(cookie)
#endif
        }
        iCloudSyncedAt = Date()
        hydratedFromICloud = true
    }

    // MARK: - Sign-in state

    /// Reads cookies from the platform-appropriate cookie source, updates
    /// published state, and (on platforms with WebKit) mirrors the WebKit
    /// store into `HTTPCookieStorage.shared`.
    public func refreshSignInState() async {
#if canImport(WebKit)
        let cookies = await dataStore.httpCookieStore.allCookies()
        let ytCookies = cookies.filter { Self.isYouTubeCookie($0) }
        for cookie in ytCookies {
            HTTPCookieStorage.shared.setCookie(cookie)
        }
#else
        let ytCookies = (HTTPCookieStorage.shared.cookies ?? []).filter { Self.isYouTubeCookie($0) }
#endif
        if let sapis = ytCookies.first(where: { $0.name == "SAPISID" })?.value {
            sapisid = sapis
            authCookies = ytCookies
            isSignedIn = true
            lastSyncedAt = Date()
#if canImport(WebKit)
            // Only iOS/mac/visionOS write the iCloud blob — tvOS is read-only.
            if Self.persistCookies(ytCookies) {
                iCloudSyncedAt = Date()
            }
#endif
        } else {
            sapisid = nil
            isSignedIn = false
        }
    }

    public func signOut() async {
#if canImport(WebKit)
        let ckStore = dataStore.httpCookieStore
        let cookies = await ckStore.allCookies()
        for cookie in cookies where Self.isYouTubeCookie(cookie) {
            await ckStore.deleteCookie(cookie)
        }
#endif
        if let shared = HTTPCookieStorage.shared.cookies {
            for cookie in shared where Self.isYouTubeCookie(cookie) {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }
        sapisid = nil
        authCookies = []
        isSignedIn = false
        hydratedFromICloud = false
        iCloudSyncedAt = nil
        Self.deleteStoredCookies()
    }

    // MARK: - SAPISIDHASH

    /// Builds the `Authorization: SAPISIDHASH …` header value YouTube's web
    /// client uses. Returns `nil` when not signed in.
    public func sapisidHashAuthorization(origin: String = "https://www.youtube.com") -> String? {
        guard let sapisid else { return nil }
        let ts = Int(Date().timeIntervalSince1970)
        let input = "\(ts) \(sapisid) \(origin)"
        let hashBytes = Insecure.SHA1.hash(data: Data(input.utf8))
        let hex = hashBytes.map { String(format: "%02x", $0) }.joined()
        return "SAPISIDHASH \(ts)_\(hex)"
    }

    /// Returns the `Cookie:` header value to attach to URLSession requests for
    /// the account. Built from the in-memory `authCookies` snapshot — NOT the
    /// live cookie stores — so it survives the window in which `StreamResolver`
    /// strips `HTTPCookieStorage.shared` for anonymous extraction.
    public func cookieHeader(for url: URL) -> String? {
        guard let host = url.host else { return nil }
        let matching = authCookies.filter { cookie in
            host.hasSuffix(cookie.domain.trimmingCharacters(in: .init(charactersIn: ".")))
                || cookie.domain.hasSuffix(host)
        }
        guard !matching.isEmpty else { return nil }
        return matching.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
    }

    // MARK: - Helpers

    static func isYouTubeCookie(_ cookie: HTTPCookie) -> Bool {
        let d = cookie.domain.trimmingCharacters(in: .init(charactersIn: "."))
        return d.hasSuffix("youtube.com") || d.hasSuffix("google.com")
    }
}

// MARK: - iCloud KVS cookie sync
//
// iOS captures cookies via WKWebView sign-in; tvOS has no interactive way to
// sign in, so we ride NSUbiquitousKeyValueStore (iCloud KVS) to replicate
// the cookie set. We use KVS rather than the synchronizable Keychain because
// the sibling FinStream project found Keychain sync unreliable on tvOS;
// KVS is the proven path. Tradeoff: the blob lives in iCloud unencrypted at
// rest by KVS, which is acceptable here since YouTube session cookies are
// already exposed within the user's iCloud account context.
//
// KVS budget: 1 MB total / 1 MB per key — far above the few-hundred-byte
// cookie blob we write. Google rotates cookies on every authenticated
// response, so iOS rewrites the KVS blob on each `refreshSignInState`.

private struct StoredCookie: Codable {
    let name: String
    let value: String
    let domain: String
    let path: String
    let expires: Date?
    let isSecure: Bool
    let isHTTPOnly: Bool

    init(_ c: HTTPCookie) {
        name = c.name
        value = c.value
        domain = c.domain
        path = c.path
        expires = c.expiresDate
        isSecure = c.isSecure
        isHTTPOnly = c.isHTTPOnly
    }

    var httpCookie: HTTPCookie? {
        var props: [HTTPCookiePropertyKey: Any] = [
            .name: name,
            .value: value,
            .domain: domain,
            .path: path,
        ]
        if isSecure { props[.secure] = "TRUE" }
        if let expires { props[.expires] = expires }
        return HTTPCookie(properties: props)
    }
}

extension YTCookieAuth {
    private static let kvsCookieKey = "cathode_yt_cookie_jar"

    /// Writes the cookie set to iCloud KVS. Returns true if KVS accepted the
    /// payload (the data also went into local KVS storage; `synchronize()`
    /// nudges the iCloud daemon to schedule an upload).
    @discardableResult
    fileprivate static func persistCookies(_ cookies: [HTTPCookie]) -> Bool {
        let stored = cookies.map(StoredCookie.init)
        guard let data = try? JSONEncoder().encode(stored) else { return false }
        let kvs = NSUbiquitousKeyValueStore.default
        kvs.set(data, forKey: kvsCookieKey)
        return kvs.synchronize()
    }

    fileprivate static func loadStoredCookies() -> [StoredCookie] {
        guard let data = NSUbiquitousKeyValueStore.default.data(forKey: kvsCookieKey)
        else { return [] }
        return (try? JSONDecoder().decode([StoredCookie].self, from: data)) ?? []
    }

    fileprivate static func deleteStoredCookies() {
        let kvs = NSUbiquitousKeyValueStore.default
        kvs.removeObject(forKey: kvsCookieKey)
        kvs.synchronize()
    }
}
