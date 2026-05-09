//
//  YTService.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 27/09/2025.
//

import Foundation

enum YTService {
    static let baseURL = "https://www.googleapis.com/youtube/v3"
    static let isoFormatter = ISO8601DateFormatter()

    private static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "com.SilverMarcs.SwiftTube"
    }

    // MARK: - Core Request Methods

    static func fetchResponse<T: Decodable>(from url: URL, forceOAuth: Bool = false) async throws -> T {
        if forceOAuth {
            return try await fetchOAuthResponse(from: url)
        }
        return try await fetchWithAPIKey(from: url)
    }

    static func fetchWithAPIKey<T: Decodable>(from url: URL) async throws -> T {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = (components.queryItems ?? []) + [URLQueryItem(name: "key", value: SecretsLocal.youtubeAPIKey)]
        var request = URLRequest(url: components.url!)
        request.setValue(bundleIdentifier, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(T.self, from: data)
    }

    static func fetchOAuthResponse<T: Decodable>(from url: URL) async throws -> T {
        guard let accessToken = KeychainManager.shared.load(key: "google_access_token"), !accessToken.isEmpty else {
            throw NSError(domain: "YTService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Missing OAuth token"])
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
