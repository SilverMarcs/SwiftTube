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
    
    private var baseURL: URL? {
        currentAccount?.instance.apiURL
    }
    
    private var token: String? {
        guard let account = currentAccount else { return nil }
        return keychainManager.loadAccountToken(account)
    }
    
    // MARK: - API Methods
    
    internal func makeAuthenticatedRequest(to endpoint: String, method: String = "GET", body: Data? = nil, useQueryToken: Bool = false) async -> Data? {
        guard currentAccount != nil, let baseURL = baseURL, let token = token else { return nil }
        
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
}
