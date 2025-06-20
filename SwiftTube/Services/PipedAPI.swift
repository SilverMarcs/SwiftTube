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
            
            // Parse JSON response
            if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                let videos = jsonArray.compactMap { videoDict in
                    parseVideo(from: videoDict)
                }
                return videos
            }
        } catch {
            print("Failed to fetch feed: \(error.localizedDescription)")
        }
        
        return []
    }
    
    func fetchSubscriptions() async -> [Channel] {
        do {
            let data = try await makeAuthenticatedRequest(to: "subscriptions")
            
            // Parse JSON response
            if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                let channels = jsonArray.compactMap { channelDict in
                    parseChannel(from: channelDict)
                }
                return channels
            }
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
            
            let body = ["channelId": channelId]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
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
            
            let body = ["channelId": channelId]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
        } catch {
            print("Failed to unsubscribe: \(error.localizedDescription)")
        }
        
        return false
    }

    // MARK: - Parsing Helpers
    
    private func parseVideo(from dict: [String: Any]) -> Video? {
        guard let url = dict["url"] as? String,
              let title = dict["title"] as? String else {
            return nil
        }
        
        // Piped uses different field names - check multiple possible fields
        let uploader = dict["uploaderName"] as? String ?? 
                      dict["uploader"] as? String ?? 
                      dict["author"] as? String ?? ""
        
        let duration = dict["duration"] as? TimeInterval ?? 0
        let views = dict["views"] as? Int ?? 0
        
        // Handle different date field formats
        var uploaded = ""
        if let uploadedTimestamp = dict["uploaded"] as? Double, uploadedTimestamp > 0 {
            let date = Date(timeIntervalSince1970: uploadedTimestamp / 1000)
            uploaded = formatRelativeTime(date)
        } else if let uploadedString = dict["uploadedDate"] as? String ?? dict["uploadDate"] as? String {
            uploaded = uploadedString
        }
        
        var thumbnailURL: URL?
        if let thumbnail = dict["thumbnail"] as? String {
            thumbnailURL = URL(string: thumbnail)
        } else if let thumbnailUrl = dict["thumbnailUrl"] as? String {
            thumbnailURL = URL(string: thumbnailUrl)
        }
        
        // Extract video ID from URL (e.g., "/watch?v=dQw4w9WgXcQ" -> "dQw4w9WgXcQ")
        let videoId = extractVideoId(from: url)
        
        let video = Video(
            id: videoId,
            title: title,
            author: uploader,
            duration: duration,
            published: uploaded,
            views: views,
            thumbnailURL: thumbnailURL
        )
        
        return video
    }
    
    private func parseChannel(from dict: [String: Any]) -> Channel? {
        guard let url = dict["url"] as? String,
              let name = dict["name"] as? String else {
            return nil
        }
        
        // Check different possible field names for subscriber count
        let subscriberCount = dict["subscriberCount"] as? Int ??
                             dict["subscribers"] as? Int ??
                             dict["uploaderSubscriberCount"] as? Int
        
        var thumbnailURL: URL?
        if let avatar = dict["avatar"] as? String {
            thumbnailURL = URL(string: avatar)
        } else if let avatarUrl = dict["avatarUrl"] as? String {
            thumbnailURL = URL(string: avatarUrl)
        } else if let uploaderAvatar = dict["uploaderAvatar"] as? String {
            thumbnailURL = URL(string: uploaderAvatar)
        }
        
        // Extract channel ID from URL
        let channelId = extractChannelId(from: url)
        
        let channel = Channel(
            id: channelId,
            name: name,
            thumbnailURL: thumbnailURL,
            subscribersCount: subscriberCount
        )
        
        return channel
    }
    
    private func extractVideoId(from url: String) -> String {
        if url.contains("watch?v=") {
            let components = url.components(separatedBy: "watch?v=")
            if components.count > 1 {
                return String(components[1].prefix(11)) // YouTube video IDs are 11 characters
            }
        }
        return url
    }
    
    private func extractChannelId(from url: String) -> String {
        if url.contains("/channel/") {
            let components = url.components(separatedBy: "/channel/")
            if components.count > 1 {
                return components[1]
            }
        }
        return url
    }
    
    private func formatRelativeTime(_ date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        let days = Int(timeInterval / 86400)
        let weeks = days / 7
        let months = days / 30
        let years = days / 365
        
        if years > 0 {
            return "\(years) year\(years == 1 ? "" : "s") ago"
        } else if months > 0 {
            return "\(months) month\(months == 1 ? "" : "s") ago"
        } else if weeks > 0 {
            return "\(weeks) week\(weeks == 1 ? "" : "s") ago"
        } else if days > 0 {
            return "\(days) day\(days == 1 ? "" : "s") ago"
        } else {
            return "Today"
        }
    }
}
