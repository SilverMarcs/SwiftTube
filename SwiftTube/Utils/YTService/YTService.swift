//
//  YTService.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 27/09/2025.
//

import Foundation

enum YTService {
    static let baseURL = "https://www.googleapis.com/youtube/v3"
    
    // MARK: - Core Request Methods
    
    static func fetchOAuthResponse<T: Decodable>(from url: URL) async throws -> T {
        let accessToken = try await GoogleAuthManager.shared.getValidAccessToken()
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        return try JSONDecoder().decode(T.self, from: data)
    }
    
//    static func fetchResponse<T: Decodable>(from url: URL) async throws -> T {
//        let (data, _) = try await URLSession.shared.data(from: url)
//        return try JSONDecoder().decode(T.self, from: data)
//    }
}
