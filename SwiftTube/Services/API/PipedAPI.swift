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
    
//    internal func makeAuthenticatedRequest(to endpoint: String, method: String = "GET", body: Data? = nil, useQueryToken: Bool = false, parameters: [String: String] = [:]) async -> Data? {
//        guard currentAccount != nil, let baseURL = baseURL, let token = token else { return nil }
//        
//        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint), resolvingAgainstBaseURL: false)
//        var queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
//        
//        if useQueryToken {
//            queryItems.append(URLQueryItem(name: "authToken", value: token))
//        }
//        
//        if !queryItems.isEmpty {
//            components?.queryItems = queryItems
//        }
//        
//        guard let finalURL = components?.url else { return nil }
//        
//        var request = URLRequest(url: finalURL)
//        request.httpMethod = method
//        
//        if !useQueryToken {
//            request.setValue(token, forHTTPHeaderField: "Authorization")
//        }
//        
//        if body != nil {
//            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//            request.httpBody = body
//        }
//        
//        do {
//            let (data, response) = try await URLSession.shared.data(for: request)
//            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }
//            return data
//        } catch {
//            return nil
//        }
//    }
    
    
//    internal func makeUnauthenticatedRequest(to endpoint: String, parameters: [String: String] = [:]) async -> Data? {
//        guard let baseURL = baseURL else { return nil }
//        
//        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint), resolvingAgainstBaseURL: false)
//        if !parameters.isEmpty {
//            components?.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
//        }
//        
//        guard let url = components?.url else { return nil }
//        
//        var request = URLRequest(url: url)
//        request.httpMethod = "GET"
//        
//        do {
//            let (data, response) = try await URLSession.shared.data(for: request)
//            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }
//            return data
//        } catch {
//            print("Unauthenticated request error: \(error.localizedDescription)")
//            return nil
//        }
//    }
    
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
            
            // Pretty print the JSON response
            if let json = try? JSONSerialization.jsonObject(with: data),
               let prettyPrintedData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
               let prettyPrintedString = String(data: prettyPrintedData, encoding: .utf8) {
                print("\n=== Raw API Response for \(method) \(endpoint) ===")
                print(prettyPrintedString)
                print("==========================================\n")
                
//                // If there's a request body, print it too
//                if let body = body,
//                   let bodyJson = try? JSONSerialization.jsonObject(with: body),
//                   let prettyPrintedBody = try? JSONSerialization.data(withJSONObject: bodyJson, options: .prettyPrinted),
//                   let prettyPrintedBodyString = String(data: prettyPrintedBody, encoding: .utf8) {
//                    print("Request Body:")
//                    print(prettyPrintedBodyString)
//                    print("==========================================\n")
//                }
            }
            
            return data
        } catch {
            print("Error making request to \(endpoint): \(error)")
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
            
            // Pretty print the JSON response
            if let json = try? JSONSerialization.jsonObject(with: data),
               let prettyPrintedData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
               let prettyPrintedString = String(data: prettyPrintedData, encoding: .utf8) {
                print("Raw API Response for \(endpoint):")
                print(prettyPrintedString)
            }
            
            return data
        } catch {
            return nil
        }
    }
}
