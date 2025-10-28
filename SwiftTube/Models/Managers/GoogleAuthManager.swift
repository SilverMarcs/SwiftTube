//
//  GoogleAuthManager.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 28/09/2025.
//

import Foundation
import AuthenticationServices

@Observable
final class GoogleAuthManager: NSObject, ASWebAuthenticationPresentationContextProviding {
    // Persisted properties (MainActor isolated for SwiftUI/UI safety)
    private(set) var accessToken: String = ""
    private var refreshToken: String = ""
    private var expirationDate: Date = Date()
    private(set) var fullName: String = ""
    private(set) var avatarUrl: String = ""
    
    // OAuth configuration
    let clientId = "551349563852-504vr1i2r82rf2ksnpj9qvu8bmc54ns8.apps.googleusercontent.com"
    let redirectUri = "com.googleusercontent.apps.551349563852-504vr1i2r82rf2ksnpj9qvu8bmc54ns8:/oauth2redirect"
    
    private var authenticationSession: ASWebAuthenticationSession?
    
    // Keychain keys
    private enum Keys {
        static let access = "google_access_token"
        static let refresh = "google_refresh_token"
        static let expiry = "google_token_expiration"
        static let name = "google_full_name"
        static let avatar = "google_avatar_url"
    }
    
    override init() {
        super.init()
        loadTokens()
    }
    
    private func loadTokens() {
        if let token = KeychainManager.shared.load(key: Keys.access) { accessToken = token }
        if let token = KeychainManager.shared.load(key: Keys.refresh) { refreshToken = token }
        if let expiryString = KeychainManager.shared.load(key: Keys.expiry),
           let seconds = TimeInterval(expiryString) {
            expirationDate = Date(timeIntervalSince1970: seconds)
        }
        if let name = KeychainManager.shared.load(key: Keys.name) { fullName = name }
        if let avatar = KeychainManager.shared.load(key: Keys.avatar) { avatarUrl = avatar }
    }
    
    private func saveTokens() {
        KeychainManager.shared.save(key: Keys.access, data: accessToken)
        KeychainManager.shared.save(key: Keys.refresh, data: refreshToken)
        KeychainManager.shared.save(key: Keys.expiry, data: String(expirationDate.timeIntervalSince1970))
        KeychainManager.shared.save(key: Keys.name, data: fullName)
        KeychainManager.shared.save(key: Keys.avatar, data: avatarUrl)
    }
    
    func clearTokens() {
        accessToken = ""
        refreshToken = ""
        expirationDate = Date()
        fullName = ""
        avatarUrl = ""
        
        KeychainManager.shared.delete(key: Keys.access)
        KeychainManager.shared.delete(key: Keys.refresh)
        KeychainManager.shared.delete(key: Keys.expiry)
        KeychainManager.shared.delete(key: Keys.name)
        KeychainManager.shared.delete(key: Keys.avatar)
    }
    
    func signIn() async throws {
        let authUrl = URL(string: "https://accounts.google.com/o/oauth2/v2/auth?client_id=\(clientId)&redirect_uri=\(redirectUri)&response_type=code&scope=https://www.googleapis.com/auth/youtube https://www.googleapis.com/auth/youtube.readonly https://www.googleapis.com/auth/youtube.upload https://www.googleapis.com/auth/youtube.force-ssl https://www.googleapis.com/auth/userinfo.profile https://www.googleapis.com/auth/userinfo.email openid")!
        let callbackUrlScheme = "com.googleusercontent.apps.551349563852-504vr1i2r82rf2ksnpj9qvu8bmc54ns8"

        return try await withCheckedThrowingContinuation { continuation in
            authenticationSession = ASWebAuthenticationSession(url: authUrl, callbackURLScheme: callbackUrlScheme) { [weak self] callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let callbackURL = callbackURL,
                      let queryItems = URLComponents(string: callbackURL.absoluteString)?.queryItems,
                      let code = queryItems.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: NSError(domain: "GoogleAuthManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to get authorization code"]))
                    return
                }

                Task {
                    do {
                        guard let self = self else { return }
                        try await self.exchangeCodeForTokens(authCode: code)
                        try await self.fetchUserInfo()
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }

            authenticationSession?.presentationContextProvider = self
            authenticationSession?.start()
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if os(iOS)
        return UIApplication.shared.windows.first ?? ASPresentationAnchor()
        #elseif os(macOS)
        return NSApplication.shared.keyWindow ?? ASPresentationAnchor()
        #endif
    }
    
    
    
    var isSignedIn: Bool {
        return !accessToken.isEmpty
    }
    
    private func refreshAccessToken() async throws -> String {
        guard !refreshToken.isEmpty else {
            throw NSError(domain: "GoogleAuthManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No refresh token available"])
        }
        
        let url = URL(string: "https://oauth2.googleapis.com/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let parameters: [String: String] = [
            "client_id": clientId,
            "client_secret": "",
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        
        let bodyString = parameters.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        guard let jsonResult = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let newAccessToken = jsonResult["access_token"] as? String,
              let expiresIn = jsonResult["expires_in"] as? TimeInterval else {
            throw NSError(domain: "GoogleAuthManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response"])
        }
        
        self.accessToken = newAccessToken
        self.expirationDate = Date().addingTimeInterval(expiresIn)
        self.saveTokens()
        
        return newAccessToken
    }
    
    func exchangeCodeForTokens(authCode: String) async throws {
        let url = URL(string: "https://oauth2.googleapis.com/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let parameters: [String: String] = [
            "client_id": clientId,
            "client_secret": "",
            "code": authCode,
            "grant_type": "authorization_code",
            "redirect_uri": redirectUri,
            "scope": "https://www.googleapis.com/auth/youtube https://www.googleapis.com/auth/youtube.readonly https://www.googleapis.com/auth/youtube.upload https://www.googleapis.com/auth/youtube.force-ssl https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/userinfo.profile openid"
        ]
        
        let bodyString = parameters.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        guard let jsonResult = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let accessToken = jsonResult["access_token"] as? String,
              let refreshToken = jsonResult["refresh_token"] as? String,
              let expiresIn = jsonResult["expires_in"] as? TimeInterval else {
            throw NSError(domain: "GoogleAuthManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response"])
        }
        
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expirationDate = Date().addingTimeInterval(expiresIn)
        self.saveTokens()
    }
    
    func fetchUserInfo() async throws {
        let token = try await getValidAccessToken()
        let url = URL(string: "https://www.googleapis.com/oauth2/v2/userinfo")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = json["name"] as? String,
              let picture = json["picture"] as? String else {
            throw NSError(domain: "GoogleAuthManager", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch user info"])
        }
        
        self.fullName = name
        self.avatarUrl = picture
        self.saveTokens()
    }
    
    func getValidAccessToken() async throws -> String {
        if Date().addingTimeInterval(5 * 60) < expirationDate && !accessToken.isEmpty {
            return accessToken
        }
        return try await refreshAccessToken()
    }
}

