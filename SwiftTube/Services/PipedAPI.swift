import Foundation
import Combine

final class PipedAPI: ObservableObject {
    static let shared = PipedAPI()
    
    @Published var isAuthenticated = false
    
    private let keychainManager = KeychainManager.shared
    
    private init() {}
    
    private var currentAccount: Account? {
        AccountManager.shared.currentAccount
    }
    
    private var baseURL: URL? {
        currentAccount?.instance.apiURL
    }
    
    private var token: String? {
        guard let account = currentAccount else { return nil }
        return keychainManager.loadAccountToken(account)
    }
    
    // MARK: - Authentication
    
    func login(username: String, password: String, account: Account) async {
        guard let baseURL = URL(string: account.instance.apiURLString) else {
            print("Invalid instance URL")
            return
        }
        
        let loginURL = baseURL.appendingPathComponent("login")
        
        var request = URLRequest(url: loginURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let credentials = ["username": username, "password": password]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: credentials)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                
                if httpResponse.statusCode == 200 {
                    let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
                    
                    
                    if let token = authResponse.token, !token.isEmpty {
                        // Save credentials and token
                        keychainManager.saveAccountCredentials(account, username: username, password: password)
                        keychainManager.saveAccountToken(account, token: token)
                        
                        isAuthenticated = true
                    } else if let error = authResponse.error {
                            print("Authentication error: \(error)")
                    } else {
                        print("No token or error in response")
                    }
                } else {
                    print("HTTP error: \(httpResponse.statusCode)")
                }
            }
        } catch {
            print("Network error: \(error.localizedDescription)")
        }
    }
    
    func logout() {
        guard let account = currentAccount else { return }
        keychainManager.deleteAccountData(account)
        isAuthenticated = false
    }
    
    // MARK: - API Methods
    
    private func makeAuthenticatedRequest(to endpoint: String, method: String = "GET", body: Data? = nil, useQueryToken: Bool = false) async -> Data? {
        guard let baseURL = baseURL, let token = token else { return nil }
        
        let url = baseURL.appendingPathComponent(endpoint)
        var finalURL = url
        
        if useQueryToken {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = [URLQueryItem(name: "authToken", value: token)]
            guard let queryURL = components?.url else { return nil }
            finalURL = queryURL
        }
        
        var request = URLRequest(url: finalURL)
        request.httpMethod = method
        
        if !useQueryToken {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }
        
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }
            return data
        } catch {
            return nil
        }
    }
    
    func fetchSubscribedFeed() async -> [Video] {
        guard let data = await makeAuthenticatedRequest(to: "feed", useQueryToken: true) else { return [] }
        
        do {
            let videoResponses = try JSONDecoder().decode([VideoResponse].self, from: data)
            return videoResponses.compactMap { $0.toVideo() }
        } catch {
            return []
        }
    }
    
    func fetchSubscriptions() async -> [Channel] {
        guard let data = await makeAuthenticatedRequest(to: "subscriptions") else { return [] }
        
        do {
            let channelResponses = try JSONDecoder().decode([ChannelResponse].self, from: data)
            return channelResponses.compactMap { $0.toChannel() }
        } catch {
            return []
        }
    }
    
    private func manageSubscription(channelId: String, endpoint: String) async -> Bool {
        guard let body = try? JSONEncoder().encode(SubscriptionRequest(channelId: channelId)) else { return false }
        return await makeAuthenticatedRequest(to: endpoint, method: "POST", body: body) != nil
    }
    
    func subscribe(to channelId: String) async -> Bool {
        return await manageSubscription(channelId: channelId, endpoint: "subscribe")
    }
    
    func unsubscribe(from channelId: String) async -> Bool {
        return await manageSubscription(channelId: channelId, endpoint: "unsubscribe")
    }

}
