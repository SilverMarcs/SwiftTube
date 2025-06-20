//
//  AuthApi.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 21/06/2025.
//

import Foundation

extension PipedAPI {
    func login(username: String, password: String, account: Account) async {
        guard let baseURL = URL(string: account.instance.apiURLString) else { return }
        
        let loginURL = baseURL.appendingPathComponent("login")
        let authRequest = AuthRequest(username: username, password: password)
        
        var request = URLRequest(url: loginURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(authRequest)
            let (data, _) = try await URLSession.shared.data(for: request)
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            
            if let token = authResponse.token, !token.isEmpty {
                keychainManager.saveAccountCredentials(account, username: username, password: password)
                keychainManager.saveAccountToken(account, token: token)
                isAuthenticated = true
            }
        } catch {
            print("Login error: \(error.localizedDescription)")
        }
    }
    
    func logout() {
        guard let account = currentAccount else { return }
        keychainManager.deleteAccountData(account)
        isAuthenticated = false
    }
}
