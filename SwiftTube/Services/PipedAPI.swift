import Foundation
import Combine

final class PipedAPI: ObservableObject {
    @Published var isAuthenticated = false
    @Published var errorMessage: String?
    
    private let account: Account
    private let keychainManager = KeychainManager.shared
    
    init(account: Account) {
        self.account = account
        checkAuthenticationStatus()
    }
    
    private var baseURL: URL? {
        account.instance.apiURL
    }
    
    private var token: String? {
        keychainManager.loadAccountToken(account)
    }
    
    private func checkAuthenticationStatus() {
        let currentToken = token
        let wasAuthenticated = isAuthenticated
        isAuthenticated = currentToken != nil && !currentToken!.isEmpty
        
        print("Auth status check - Token exists: \(currentToken != nil), Token empty: \(currentToken?.isEmpty ?? true), Was authenticated: \(wasAuthenticated), Now authenticated: \(isAuthenticated)")
        
        if let token = currentToken {
            print("Token preview: \(String(token.prefix(10)))...")
        }
    }
    // MARK: - Authentication
    
    func login(username: String, password: String) async {
        guard let baseURL = baseURL else {
            await MainActor.run {
                errorMessage = "Invalid instance URL"
            }
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
                print("Login response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
                    
                    print("Auth response - token exists: \(authResponse.token != nil), error: \(authResponse.error ?? "none")")
                    
                    if let token = authResponse.token, !token.isEmpty {
                        // Save credentials and token
                        keychainManager.saveAccountCredentials(account, username: username, password: password)
                        keychainManager.saveAccountToken(account, token: token)
                        
                        await MainActor.run {
                            isAuthenticated = true
                            errorMessage = nil
                        }
                        print("Login successful, token saved")
                    } else if let error = authResponse.error {
                        await MainActor.run {
                            errorMessage = error
                        }
                        print("Login error: \(error)")
                    } else {
                        await MainActor.run {
                            errorMessage = "Authentication failed"
                        }
                        print("Login failed: no token or error in response")
                    }
                } else {
                    let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
                    await MainActor.run {
                        errorMessage = "HTTP error: \(httpResponse.statusCode)"
                    }
                    print("HTTP error \(httpResponse.statusCode): \(responseBody)")
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Network error: \(error.localizedDescription)"
            }
            print("Network error: \(error)")
        }
    }
    
    func logout() {
        keychainManager.deleteAccountData(account)
        isAuthenticated = false
        errorMessage = nil
    }
    
    // MARK: - Authenticated Requests
    
    private func makeAuthenticatedRequest(to endpoint: String) async throws -> Data {
        guard let baseURL = baseURL else {
            throw URLError(.badURL)
        }
        
        guard let token = token else {
            print("No token available for \(endpoint) request")
            throw URLError(.userAuthenticationRequired)
        }
        
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.setValue(token, forHTTPHeaderField: "Authorization")
        
        print("Making authenticated request to: \(url.absoluteString)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("\(endpoint) request response status: \(httpResponse.statusCode)")
            guard httpResponse.statusCode == 200 else {
                print("\(endpoint) request failed with status: \(httpResponse.statusCode)")
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
            print("No token available for feed request")
            throw URLError(.userAuthenticationRequired)
        }
        
        let url = baseURL.appendingPathComponent("feed")
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        urlComponents?.queryItems = [URLQueryItem(name: "authToken", value: token)]
        
        guard let finalURL = urlComponents?.url else {
            throw URLError(.badURL)
        }
        
        print("Making feed request to: \(finalURL.absoluteString)")
        
        let request = URLRequest(url: finalURL)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("Feed request response status: \(httpResponse.statusCode)")
            guard httpResponse.statusCode == 200 else {
                print("Feed request failed with status: \(httpResponse.statusCode)")
                throw URLError(.badServerResponse)
            }
        }
        
        return data
    }
    
    // MARK: - Feed Methods
    
    func fetchSubscribedFeed() async -> [Video] {
        do {
            print("Fetching subscribed feed...")
            let data = try await makeFeedRequest()
            print("Feed data received: \(data.count) bytes")
            
            // Parse JSON response
            if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                print("Parsed \(jsonArray.count) videos from feed")
                
                // Debug: print first video structure if available
                if let firstVideo = jsonArray.first {
                    print("First video keys: \(firstVideo.keys.sorted())")
                    print("Sample video data: \(firstVideo)")
                }
                
                let videos = jsonArray.compactMap { videoDict in
                    parseVideo(from: videoDict)
                }
                print("Successfully parsed \(videos.count) videos")
                return videos
            } else {
                print("Failed to parse feed response as JSON array")
                // Try to see what we actually got
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Response was: \(String(jsonString.prefix(1000)))...")
                }
            }
        } catch {
            print("Error fetching feed: \(error)")
            await MainActor.run {
                errorMessage = "Failed to fetch feed: \(error.localizedDescription)"
            }
        }
        
        return []
    }
    
    func fetchSubscriptions() async -> [Channel] {
        do {
            print("Fetching subscriptions...")
            let data = try await makeAuthenticatedRequest(to: "subscriptions")
            print("Subscriptions data received: \(data.count) bytes")
            
            // Parse JSON response
            if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                print("Parsed \(jsonArray.count) channels from subscriptions")
                let channels = jsonArray.compactMap { channelDict in
                    parseChannel(from: channelDict)
                }
                print("Successfully parsed \(channels.count) channels")
                return channels
            } else {
                print("Failed to parse subscriptions response as JSON array")
                // Try to see what we actually got
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Response was: \(jsonString)")
                }
            }
        } catch {
            print("Error fetching subscriptions: \(error)")
            await MainActor.run {
                errorMessage = "Failed to fetch subscriptions: \(error.localizedDescription)"
            }
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
            await MainActor.run {
                errorMessage = "Failed to subscribe: \(error.localizedDescription)"
            }
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
            await MainActor.run {
                errorMessage = "Failed to unsubscribe: \(error.localizedDescription)"
            }
        }
        
        return false
    }

    // MARK: - Parsing Helpers
    
    private func parseVideo(from dict: [String: Any]) -> Video? {
        guard let url = dict["url"] as? String,
              let title = dict["title"] as? String else {
            print("Missing required fields in video dict: \(dict.keys.sorted())")
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
        
        print("Successfully parsed video: \(title) by \(uploader)")
        return video
    }
    
    private func parseChannel(from dict: [String: Any]) -> Channel? {
        guard let url = dict["url"] as? String,
              let name = dict["name"] as? String else {
            print("Missing required fields in channel dict: \(dict.keys.sorted())")
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
        
        print("Successfully parsed channel: \(name)")
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
