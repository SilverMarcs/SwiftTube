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
    
    static var apiKey: String? {
        UserDefaults.standard.string(forKey: "youtubeAPIKey")
    }
    
    // MARK: - Core Request Methods
    
    static func fetchResponse<T: Decodable>(from url: URL) async throws -> T {
        if let apiKey = apiKey, !apiKey.isEmpty {
            return try await fetchWithAPIKey(from: url)
        } else {
            return try await fetchOAuthResponse(from: url)
        }
    }
    
    static func fetchWithAPIKey<T: Decodable>(from url: URL) async throws -> T {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = (components.queryItems ?? []) + [URLQueryItem(name: "key", value: apiKey!)]
        let request = URLRequest(url: components.url!)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    static func fetchOAuthResponse<T: Decodable>(from url: URL) async throws -> T {
        let accessToken = try await GoogleAuthManager.shared.getValidAccessToken()
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
