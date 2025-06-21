import Foundation
import Combine

final class PipedAPI {
    static let shared = PipedAPI()
    
    var isAuthenticated = false
    
    internal let keychainManager = KeychainManager.shared
    
    private init() {}
    
    internal var currentAccount: Account? {
        AccountManager.shared.currentAccount
    }
    
    internal var baseURL: URL? {
        currentAccount?.instance.apiURL
    }
    
    private var token: String? {
        guard let account = currentAccount else { return nil }
        return keychainManager.loadAccountToken(account)
    }
    
    // MARK: - API Methods
    internal func makeAuthenticatedRequest(to endpoint: String, method: String = "GET", body: Data? = nil, useQueryToken: Bool = false, parameters: [String: String] = [:]) async -> Data? {
        guard currentAccount != nil, let baseURL = baseURL, let token = token else { return nil }
        
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint), resolvingAgainstBaseURL: false)
        var queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        if useQueryToken {
            queryItems.append(URLQueryItem(name: "authToken", value: token))
        }
        
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        
        guard let finalURL = components?.url else { return nil }
        
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
            
            Logger.logAPIResponse(data, endpoint: endpoint, method: method)
            
            return data
        } catch {
            Logger.logError("Making request to \(endpoint): \(error)")
            return nil
        }
    }
    
    internal func makeUnauthenticatedRequest(to endpoint: String, parameters: [String: String] = [:]) async -> Data? {
        guard let baseURL = baseURL else { return nil }
        
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint), resolvingAgainstBaseURL: false)
        if !parameters.isEmpty {
            components?.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        
        guard let url = components?.url else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }
            
            Logger.logAPIResponse(data, endpoint: endpoint)
            
            return data
        } catch {
            Logger.logError("Unauthenticated request to \(endpoint): \(error.localizedDescription)")
            return nil
        }
    }
}
