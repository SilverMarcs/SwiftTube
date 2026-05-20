//
//  YTTVAuthManager.swift
//  Cathode
//
//  YouTube TV device-code OAuth flow.
//  Ported from SmartTubeIOS AuthService (RFC 8628 device authorization grant).
//
//  Differences from Cathode's previous GoogleAuthManager:
//   - No ASWebAuthenticationSession; works on tvOS.
//   - No redirect URI, no registered client_id — credentials are scraped from
//     YouTube TV's own base.js (mirrors Android SmartTube).
//   - Token observation pushes the bearer into `InnerTubeAPI.shared.setAuthToken(...)`.
//

import Foundation
import Observation
import os

private let authLog = Logger(subsystem: appSubsystem, category: "YTTVAuth")

@MainActor
@Observable
public final class YTTVAuthManager {

    // MARK: - Singleton

    public static let shared = YTTVAuthManager()

    // MARK: - Observable state

    public internal(set) var isSignedIn: Bool = false
    public internal(set) var accountName: String?
    public internal(set) var accountAvatarURL: URL?
    public var error: Error?

    /// Non-nil while waiting for the user to enter the code at youtube.com/activate.
    public internal(set) var pendingActivation: ActivationInfo?

    public struct ActivationInfo: Sendable {
        /// Short code the user types at youtube.com/activate (e.g. "ABCD-1234").
        public let userCode: String
        /// Verification URL — typically https://yt.be/activate or https://www.google.com/device.
        public let verificationURL: URL
        /// When this activation attempt expires.
        public let expiresAt: Date
    }

    // MARK: - Internal state

    public internal(set) var accessToken: String?
    var refreshToken: String?
    var tokenExpiry: Date?
    var pollTask: Task<Void, Never>?

    var credentialsFetcher = YouTubeClientCredentialsFetcher()
    var scope = "http://gdata.youtube.com https://www.googleapis.com/auth/youtube-paid-content"
    private var tokenRefreshTask: Task<Void, Never>?

    private var currentDeviceCode: String?
    private var currentInterval: TimeInterval = 5
    private var currentCreds: YouTubeClientCredentials?
    private var isSigningIn: Bool = false

    public let tokenManager: TokenManager

    // MARK: - Static endpoint URLs

    static let deviceCodeURL   = URL(string: "https://oauth2.googleapis.com/device/code")!
    static let tokenURL        = URL(string: "https://oauth2.googleapis.com/token")!
    static let accountsListURL = URL(string: "https://www.youtube.com/youtubei/v1/account/accounts_list")!

    private init() {
        tokenManager = TokenManager()
        loadFromKeychain()
        // Push the bootstrapped token into InnerTubeAPI.shared.
        if let t = accessToken {
            Task { await InnerTubeAPI.shared.setAuthToken(t) }
        }
        // Background-refresh user info if missing (older keychain layout).
        if isSignedIn && accountName == nil {
            Task {
                do { try await fetchUserInfo() }
                catch { authLog.error("fetchUserInfo on init failed: \(String(describing: error), privacy: .public)") }
            }
        }
    }

    // MARK: - Public API

    /// Step 1 – request a device code and expose the user_code for display.
    public func beginSignIn() async {
        guard !isSigningIn else {
            authLog.notice("beginSignIn() — already in progress, ignoring duplicate call")
            return
        }
        isSigningIn = true
        defer { isSigningIn = false }
        pollTask?.cancel()
        error = nil
        pendingActivation = nil
        authLog.notice("beginSignIn() — fetching credentials…")

        let creds = await credentialsFetcher.credentials()
        authLog.notice("Using clientId: \(creds.clientId, privacy: .public)")

        do {
            let deviceResponse = try await retryWithBackoff { [self] in
                try await requestDeviceCode(creds: creds)
            }
            authLog.notice("Got device code. userCode=\(deviceResponse.userCode, privacy: .public) expiresIn=\(deviceResponse.expiresIn)s interval=\(deviceResponse.interval)s")
            let expiresAt = Date().addingTimeInterval(TimeInterval(deviceResponse.expiresIn))
            let fallbackURL = URL(string: "https://yt.be/activate") ?? URL(string: "https://youtube.com/activate")!
            let verURL = URL(string: deviceResponse.verificationURL) ?? fallbackURL

            pendingActivation = ActivationInfo(
                userCode: deviceResponse.userCode,
                verificationURL: verURL,
                expiresAt: expiresAt
            )

            let interval = max(TimeInterval(deviceResponse.interval), 5)
            currentDeviceCode = deviceResponse.deviceCode
            currentInterval   = interval
            currentCreds      = creds
            pollTask = Task { [weak self] in
                await self?.pollForToken(deviceCode: deviceResponse.deviceCode,
                                         interval: interval,
                                         creds: creds)
            }
        } catch {
            authLog.error("beginSignIn error: \(String(describing: error), privacy: .public)")
            self.error = error
        }
    }

    public func cancelSignIn() {
        pollTask?.cancel()
        pollTask = nil
        pendingActivation = nil
        currentDeviceCode = nil
        currentCreds      = nil
    }

    /// Call when the app returns to the foreground while a sign-in is in progress.
    public func handleForeground() {
        guard !isSignedIn, accessToken == nil else { return }
        guard let pending = pendingActivation, pending.expiresAt > Date() else { return }
        guard let deviceCode = currentDeviceCode, let creds = currentCreds else { return }
        authLog.notice("handleForeground() — restarting poll immediately")
        pollTask?.cancel()
        let interval = currentInterval
        pollTask = Task { [weak self] in
            await self?.pollForToken(deviceCode: deviceCode,
                                     interval: interval,
                                     creds: creds,
                                     pollImmediately: true)
        }
    }

    /// Refreshes the access token now if it has expired or expires within 5 minutes.
    public func refreshIfNeeded() async {
        guard isSignedIn, let expiry = tokenExpiry else { return }
        guard expiry.timeIntervalSinceNow < 5 * 60 else { return }
        guard let refresh = refreshToken else { return }
        authLog.notice("refreshIfNeeded() — token expires soon, refreshing")
        let creds = await credentialsFetcher.credentials()
        do {
            try await refreshAccessToken(refreshToken: refresh, creds: creds)
        } catch {
            authLog.error("refreshIfNeeded() failed: \(String(describing: error), privacy: .public)")
        }
    }

    public func signOut() {
        pollTask?.cancel()
        pollTask = nil
        tokenRefreshTask?.cancel()
        tokenRefreshTask = nil
        accessToken      = nil
        refreshToken     = nil
        tokenExpiry      = nil
        accountName      = nil
        accountAvatarURL = nil
        isSignedIn       = false
        pendingActivation = nil
        clearKeychain()
        Task { await InnerTubeAPI.shared.setAuthToken(nil) }
    }

    /// Returns a valid access token, refreshing if necessary.
    public func validAccessToken() async throws -> String {
        if let t = accessToken, let exp = tokenExpiry, exp > Date() { return t }
        guard let refresh = refreshToken else { throw ITAuthError.notSignedIn }
        let creds = await credentialsFetcher.credentials()
        try await retryWithBackoff(maxAttempts: 2) { [self] in
            try await refreshAccessToken(refreshToken: refresh, creds: creds)
        }
        guard let t = accessToken else { throw ITAuthError.notSignedIn }
        return t
    }

    // MARK: - Proactive token refresh

    func scheduleProactiveRefresh() {
        tokenRefreshTask?.cancel()
        guard let expiry = tokenExpiry, refreshToken != nil else { return }
        let delay = max(expiry.timeIntervalSinceNow - 5 * 60, 0)
        authLog.notice("scheduleProactiveRefresh() — refreshing in \(Int(delay))s")
        tokenRefreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            guard self.isSignedIn, let refresh = self.refreshToken else { return }
            let creds = await self.credentialsFetcher.credentials()
            do {
                try await self.refreshAccessToken(refreshToken: refresh, creds: creds)
                authLog.notice("scheduleProactiveRefresh() — token refreshed")
                self.scheduleProactiveRefresh()
            } catch {
                authLog.error("scheduleProactiveRefresh() failed: \(String(describing: error), privacy: .public)")
            }
        }
    }
}

// MARK: - ITAuthError

public enum ITAuthError: LocalizedError {
    case cancelled
    case missingCode
    case tokenExchangeFailed
    case notSignedIn
    case configurationError
    case deviceCodeRequestFailed
    case authorizationPending
    case slowDown
    case deviceCodeExpired

    public var errorDescription: String? {
        switch self {
        case .cancelled:              return "Sign-in was cancelled"
        case .missingCode:            return "OAuth code was missing from callback"
        case .tokenExchangeFailed:    return "Failed to exchange code for tokens"
        case .notSignedIn:            return "You are not signed in"
        case .configurationError:     return "OAuth credentials could not be obtained"
        case .deviceCodeRequestFailed:return "Could not start sign-in. Check your internet connection."
        case .authorizationPending:   return "Waiting for authorisation…"
        case .slowDown:               return "Too many requests — slowing down"
        case .deviceCodeExpired:      return "The sign-in code expired. Please try again."
        }
    }
}

// MARK: - Device flow

extension YTTVAuthManager {

    struct DeviceCodeResponse {
        let deviceCode: String
        let userCode: String
        let verificationURL: String
        let expiresIn: Int
        let interval: Int
    }

    func requestDeviceCode(creds: YouTubeClientCredentials) async throws -> DeviceCodeResponse {
        var req = URLRequest(url: Self.deviceCodeURL)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = formEncode([
            "client_id":     creds.clientId,
            "client_secret": creds.clientSecret,
            "scope":         scope,
        ])

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ITAuthError.deviceCodeRequestFailed
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let deviceCode = json["device_code"]       as? String,
              let userCode   = json["user_code"]         as? String,
              let verURL     = json["verification_url"]  as? String,
              let expiresIn  = json["expires_in"]        as? Int
        else { throw ITAuthError.deviceCodeRequestFailed }

        return DeviceCodeResponse(
            deviceCode:      deviceCode,
            userCode:        userCode,
            verificationURL: verURL,
            expiresIn:       expiresIn,
            interval:        json["interval"] as? Int ?? 5
        )
    }

    func pollForToken(
        deviceCode: String,
        interval: TimeInterval,
        creds: YouTubeClientCredentials,
        pollImmediately: Bool = false
    ) async {
        authLog.notice("Starting poll loop (interval \(Int(interval))s, immediate=\(pollImmediately))")
        var skipInitialSleep = pollImmediately
        while !Task.isCancelled {
            if skipInitialSleep {
                skipInitialSleep = false
            } else {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }

            do {
                try await exchangeDeviceCode(deviceCode: deviceCode, creds: creds)
                authLog.notice("Token exchanged — fetching user info")
                try await fetchUserInfo()
                authLog.notice("Signed in as \(self.accountName ?? "unknown", privacy: .public)")
                pendingActivation = nil
                pollTask = nil
                return
            } catch ITAuthError.authorizationPending {
                continue
            } catch ITAuthError.slowDown {
                authLog.notice("slow_down received — waiting extra 5s")
                try? await Task.sleep(nanoseconds: UInt64(5 * 1_000_000_000))
                continue
            } catch let urlError as URLError {
                authLog.notice("Network error during poll (transient, retrying): \(urlError.localizedDescription, privacy: .public)")
                continue
            } catch {
                authLog.error("Poll error: \(String(describing: error), privacy: .public)")
                if isSignedIn { return }
                self.error = error
                pendingActivation = nil
                pollTask = nil
                return
            }
        }
    }

    func exchangeDeviceCode(deviceCode: String, creds: YouTubeClientCredentials) async throws {
        var req = URLRequest(url: Self.tokenURL)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = formEncode([
            "code":          deviceCode,
            "client_id":     creds.clientId,
            "client_secret": creds.clientSecret,
            "grant_type":    "http://oauth.net/grant_type/device/1.0",
        ])

        let (data, response) = try await URLSession.shared.data(for: req)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ITAuthError.tokenExchangeFailed
        }

        if let oauthError = json["error"] as? String {
            switch oauthError {
            case "authorization_pending": throw ITAuthError.authorizationPending
            case "slow_down":             throw ITAuthError.slowDown
            case "access_denied":         throw ITAuthError.cancelled
            case "expired_token":         throw ITAuthError.deviceCodeExpired
            default:                      throw ITAuthError.tokenExchangeFailed
            }
        }

        guard (200..<300).contains(statusCode) else { throw ITAuthError.tokenExchangeFailed }

        accessToken = json["access_token"] as? String
        if let r = json["refresh_token"] as? String { refreshToken = r }
        if let exp = json["expires_in"] as? TimeInterval {
            tokenExpiry = Date().addingTimeInterval(exp - 60)
        }
        let wasSignedIn = isSignedIn
        isSignedIn = accessToken != nil
        saveToKeychain()
        pushTokenToAPI()
        scheduleProactiveRefresh()
        if !wasSignedIn && isSignedIn {
            NotificationCenter.default.post(name: LibraryStore.signInChangedNotification, object: nil)
        }
    }

    func refreshAccessToken(refreshToken: String, creds: YouTubeClientCredentials) async throws {
        var req = URLRequest(url: Self.tokenURL)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = formEncode([
            "refresh_token": refreshToken,
            "client_id":     creds.clientId,
            "client_secret": creds.clientSecret,
            "grant_type":    "refresh_token",
        ])

        let (data, response) = try await URLSession.shared.data(for: req)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        if (statusCode == 400 || statusCode == 401),
           let errJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let oauthError = errJson["error"] as? String,
           ["invalid_grant", "invalid_client", "unauthorized_client"].contains(oauthError) {
            authLog.error("refreshAccessToken: permanent failure (\(oauthError, privacy: .public)) — signing out")
            signOut()
            throw ITAuthError.tokenExchangeFailed
        }

        guard (200..<300).contains(statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw ITAuthError.tokenExchangeFailed }

        accessToken = json["access_token"] as? String
        if let exp = json["expires_in"] as? TimeInterval {
            tokenExpiry = Date().addingTimeInterval(exp - 60)
        }
        isSignedIn = accessToken != nil
        saveToKeychain()
        pushTokenToAPI()
        scheduleProactiveRefresh()
    }
}

// MARK: - User info

extension YTTVAuthManager {

    public func fetchUserInfo() async throws {
        let token = try await validAccessToken()
        var req = URLRequest(url: Self.accountsListURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "context": [
                "client": [
                    "hl": "en",
                    "gl": "US",
                    "clientName": InnerTubeClients.TV.name,
                    "clientVersion": InnerTubeClients.TV.version,
                ]
            ],
            "accountReadMask": [
                "returnOwner": true,
                "returnBrandAccounts": true,
                "returnPersonaAccounts": false
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        guard let item = extractAccountItem(from: json) else { return }
        if let nameDict = item["accountName"] as? [String: Any] {
            accountName = (nameDict["runs"] as? [[String: Any]])?.compactMap { $0["text"] as? String }.joined()
                ?? nameDict["simpleText"] as? String
        }
        if let photoDict = item["accountPhoto"] as? [String: Any],
           let thumbnails = photoDict["thumbnails"] as? [[String: Any]],
           let last = thumbnails.last,
           let urlStr = last["url"] as? String {
            accountAvatarURL = URL(string: urlStr.hasPrefix("//") ? "https:\(urlStr)" : urlStr)
        }
        saveToKeychain()
    }

    func extractAccountItem(from json: [String: Any]) -> [String: Any]? {
        guard let contents = json["contents"] as? [[String: Any]],
              let firstSection = contents.first,
              let sectionListRenderer = firstSection["accountSectionListRenderer"] as? [String: Any],
              let sectionContents = sectionListRenderer["contents"] as? [[String: Any]],
              let firstItemSection = sectionContents.first,
              let itemSectionRenderer = firstItemSection["accountItemSectionRenderer"] as? [String: Any],
              let items = itemSectionRenderer["contents"] as? [[String: Any]]
        else { return nil }
        return items.compactMap { $0["accountItem"] as? [String: Any] }
            .first(where: { $0["isSelected"] as? Bool == true })
            ?? items.compactMap { $0["accountItem"] as? [String: Any] }.first
    }
}

// MARK: - Keychain (delegates to TokenManager)

extension YTTVAuthManager {

    func saveToKeychain() {
        let access = accessToken
        let refresh = refreshToken
        let expiry = tokenExpiry
        let name = accountName
        let avatar = accountAvatarURL
        Task {
            await tokenManager.setToken(
                access: access,
                refresh: refresh,
                expiry: expiry,
                accountName: name,
                avatarURL: avatar
            )
        }
    }

    func loadFromKeychain() {
        let snap = tokenManager.initialSnapshot
        accessToken      = snap.accessToken
        refreshToken     = snap.refreshToken
        tokenExpiry      = snap.tokenExpiry
        accountName      = snap.accountName
        accountAvatarURL = snap.accountAvatarURL
        if let expiry = tokenExpiry, expiry <= Date() {
            accessToken = nil
        }
        isSignedIn = accessToken != nil || refreshToken != nil
        if isSignedIn { scheduleProactiveRefresh() }
    }

    func clearKeychain() {
        Task { await tokenManager.clearToken() }
    }

    func pushTokenToAPI() {
        let t = accessToken
        Task { await InnerTubeAPI.shared.setAuthToken(t) }
    }
}

// MARK: - Helpers

func formEncode(_ params: [String: String]) -> Data {
    let allowed: CharacterSet = {
        var cs = CharacterSet.urlQueryAllowed
        // Reserved characters that must be percent-encoded in form bodies.
        cs.remove(charactersIn: "&=+;")
        return cs
    }()
    let body = params.map { key, value in
        let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
        let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
        return "\(k)=\(v)"
    }.joined(separator: "&")
    return body.data(using: .utf8) ?? Data()
}
