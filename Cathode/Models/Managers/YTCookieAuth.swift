//
//  YTCookieAuth.swift
//  Cathode
//
//  Cookie-based YouTube auth. Augments YTTVAuthManager (TV device-code OAuth).
//
//  Sign-in flow: user authenticates inside a WKWebView pointed at
//  accounts.google.com → continues to youtube.com. The resulting session
//  cookies (SAPISID, __Secure-3PSID, HSID, SSID, APISID, LOGIN_INFO) live in
//  `WKWebsiteDataStore.default()`, which is also the data store used by
//  `YouTubePlayerKit` — so iframe playback automatically syncs watch progress
//  to YouTube's servers.
//
//  For native AVPlayer playback, we extract the `SAPISID` cookie, compute the
//  SAPISIDHASH header YouTube's web client uses, and attach it to authenticated
//  /player calls so we can get back account-bound watchtime tracking URLs.
//

import CryptoKit
import Foundation
import os
import SwiftUI
import WebKit

private let cookieLog = Logger(subsystem: appSubsystem, category: "YTCookieAuth")

@MainActor
@Observable
public final class YTCookieAuth {
    public static let shared = YTCookieAuth()

    public private(set) var isSignedIn: Bool = false
    public private(set) var lastSyncedAt: Date?

    /// Current SAPISID cookie value — used to derive the SAPISIDHASH header.
    /// Refreshed every time `refreshSignInState()` runs.
    private(set) var sapisid: String?

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

    private init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        dataStorePrimer = WKWebView(frame: .zero, configuration: config)
        Task { await self.bootstrapSignInState() }
    }

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
        await refreshSignInState()
    }

    // MARK: - Sign-in state

    /// Reads cookies from the WebKit data store, updates published state, and
    /// mirrors them into `HTTPCookieStorage.shared` so plain `URLSession`
    /// requests to YouTube include them automatically.
    public func refreshSignInState() async {
        let cookies = await dataStore.httpCookieStore.allCookies()
        let ytCookies = cookies.filter { Self.isYouTubeCookie($0) }
        for cookie in ytCookies {
            HTTPCookieStorage.shared.setCookie(cookie)
        }
        if let sapis = ytCookies.first(where: { $0.name == "SAPISID" })?.value {
            sapisid = sapis
            isSignedIn = true
            lastSyncedAt = Date()
            cookieLog.notice("YT cookie auth: signed in (\(ytCookies.count, privacy: .public) cookies)")
        } else {
            sapisid = nil
            isSignedIn = false
        }
    }

    public func signOut() async {
        let ckStore = dataStore.httpCookieStore
        let cookies = await ckStore.allCookies()
        for cookie in cookies where Self.isYouTubeCookie(cookie) {
            await ckStore.deleteCookie(cookie)
        }
        if let shared = HTTPCookieStorage.shared.cookies {
            for cookie in shared where Self.isYouTubeCookie(cookie) {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }
        sapisid = nil
        isSignedIn = false
        cookieLog.notice("YT cookie auth: signed out")
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

    /// Returns the `Cookie:` header value to attach to URLSession requests
    /// when we can't rely on `HTTPCookieStorage.shared` being honoured.
    public func cookieHeader(for url: URL) async -> String? {
        let cookies = await dataStore.httpCookieStore.allCookies()
        let matching = cookies.filter { cookie in
            guard let host = url.host else { return false }
            return host.hasSuffix(cookie.domain.trimmingCharacters(in: .init(charactersIn: ".")))
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
