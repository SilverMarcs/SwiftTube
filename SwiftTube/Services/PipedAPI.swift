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
    
    // MARK: - Authenticated Requests
    
    private func makeAuthenticatedRequest(to endpoint: String) async throws -> Data {
        guard let baseURL = baseURL else {
            throw URLError(.badURL)
        }
        
        guard let token = token else {
            throw URLError(.userAuthenticationRequired)
        }
        
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.setValue(token, forHTTPHeaderField: "Authorization")
        
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            guard httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
        }
        
        return data
    }
    
    private func makeFeedRequest() async throws -> Data {
        guard let baseURL = baseURL else {
            throw URLError(.badURL)
        }
        
        guard let token = token else {
            throw URLError(.userAuthenticationRequired)
        }
        
        let url = baseURL.appendingPathComponent("feed")
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        urlComponents?.queryItems = [URLQueryItem(name: "authToken", value: token)]
        
        guard let finalURL = urlComponents?.url else {
            throw URLError(.badURL)
        }
        
        
        let request = URLRequest(url: finalURL)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            guard httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
        }
        
        return data
    }
    
    // MARK: - Feed Methods
    
    func fetchSubscribedFeed() async -> [Video] {
        do {
            let data = try await makeFeedRequest()
            
            let videoResponses = try JSONDecoder().decode([VideoResponse].self, from: data)
            let videos = videoResponses.compactMap { $0.toVideo() }
            return videos
        } catch {
            print("Failed to fetch feed: \(error.localizedDescription)")
        }
        
        return []
    }
    
    func fetchSubscriptions() async -> [Channel] {
        do {
            let data = try await makeAuthenticatedRequest(to: "subscriptions")
            
            let channelResponses = try JSONDecoder().decode([ChannelResponse].self, from: data)
            let channels = channelResponses.compactMap { $0.toChannel() }
            return channels
        } catch {
            print("Failed to fetch subscriptions: \(error.localizedDescription)")
        }
        
        return []
    }
    
    func subscribe(to channelId: String) async -> Bool {
        do {
            let endpoint = "subscribe"
            guard let baseURL = baseURL else { return false }
            guard let token = token else { return false }
            
            let url = baseURL.appendingPathComponent(endpoint)
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue(token, forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let subscriptionRequest = SubscriptionRequest(channelId: channelId)
            request.httpBody = try JSONEncoder().encode(subscriptionRequest)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
        } catch {
            print("Failed to subscribe: \(error.localizedDescription)")
        }
        
        return false
    }
    
    func unsubscribe(from channelId: String) async -> Bool {
        do {
            let endpoint = "unsubscribe"
            guard let baseURL = baseURL else { return false }
            guard let token = token else { return false }
            
            let url = baseURL.appendingPathComponent(endpoint)
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue(token, forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let subscriptionRequest = SubscriptionRequest(channelId: channelId)
            request.httpBody = try JSONEncoder().encode(subscriptionRequest)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
        } catch {
            print("Failed to unsubscribe: \(error.localizedDescription)")
        }
        
        return false
    }

}
