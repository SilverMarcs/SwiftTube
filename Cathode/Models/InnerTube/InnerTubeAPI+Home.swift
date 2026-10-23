import Foundation

extension InnerTubeAPI {
    func fetchHomePage(continuationToken: String? = nil) async throws -> HomeFeedPage {
        let token = try await YTTVAuthManager.shared.validAccessToken()
        var body = makeBody(client: tvClientContext, continuationToken: continuationToken, includeVisitorData: true)
        if continuationToken == nil { body["browseId"] = "FEwhat_to_watch" }
        let data = try await postTV(endpoint: "browse", body: body, explicitBearerToken: token)
        updateVisitorData(from: data)
        return parseHomePage(from: data)
    }

    /// WEB Home via the cookie session, used only for the channel links and
    /// avatars TV tiles omit. Empty without a cookie sign-in.
    func fetchWebHomeVideos() async throws -> [Video] {
        await YTCookieAuth.shared.refreshSignInState()
        guard await YTCookieAuth.shared.sapisidHashAuthorization() != nil else { return [] }
        var body = makeBody(client: webClientContext)
        body["browseId"] = "FEwhat_to_watch"
        let data = try await postWebAuthenticated(endpoint: "browse", body: body)
        return try parseVideoGroup(from: data, title: nil).videos
    }

    func fetchHomeShelfContinuation(continuationToken: String) async throws -> VideoGroup {
        let token = try await YTTVAuthManager.shared.validAccessToken()
        let body = makeBody(client: tvClientContext, continuationToken: continuationToken)
        let data = try await postTV(endpoint: "browse", body: body, explicitBearerToken: token)
        return try parseVideoGroup(from: data, title: nil)
    }

    func parseHomePage(from json: [String: Any]) -> HomeFeedPage {
        var shelves: [VideoGroup] = []
        var nextPageToken: String?
        var stack: [(Any, Int)] = [(json, 0)]
        while let (value, depth) = stack.popLast() {
            guard depth < 50 else { continue }
            if let dictionary = value as? [String: Any] {
                if ["adSlotRenderer", "adRenderer", "promotedSparklesVideoRenderer", "promotedVideoRenderer"]
                    .contains(where: { dictionary[$0] != nil }) { continue }
                if let section = (dictionary["sectionListRenderer"] ?? dictionary["sectionListContinuation"]) as? [String: Any] {
                    nextPageToken = homeContinuation(in: section)
                    stack.append((section["contents"] as Any, depth + 1))
                    continue
                }
                if let shelf = dictionary["shelfRenderer"] as? [String: Any] {
                    let header = (shelf["headerRenderer"] as? [String: Any])?["shelfHeaderRenderer"] as? [String: Any]
                    let avatar = (header?["avatarLockup"] as? [String: Any])?["avatarLockupRenderer"] as? [String: Any]
                    let title = [shelf["title"], avatar?["title"], header?["title"]]
                        .compactMap { ($0 as? [String: Any]).flatMap { extractText($0) } }
                        .first { !$0.isEmpty }
                    let content = shelf["content"] as? [String: Any] ?? [:]
                    if var group = try? parseVideoGroup(from: content, title: title), !group.videos.isEmpty {
                        let horizontal = content["horizontalListRenderer"] as? [String: Any]
                        group.nextPageToken = horizontal.flatMap { homeContinuation(in: $0) }
                        shelves.append(group)
                    }
                    // Never consume a shelf's horizontal token as the page token.
                    continue
                }
                if let item = dictionary["continuationItemRenderer"] as? [String: Any],
                   let endpoint = item["continuationEndpoint"] as? [String: Any],
                   let command = endpoint["continuationCommand"] as? [String: Any],
                   let token = command["token"] as? String {
                    nextPageToken = token
                    continue
                }
                for key in dictionary.keys.sorted().reversed() {
                    stack.append((dictionary[key] as Any, depth + 1))
                }
            } else if let array = value as? [Any] {
                for item in array.reversed() { stack.append((item, depth + 1)) }
            }
        }
        return HomeFeedPage(shelves: shelves, nextPageToken: nextPageToken)
    }

    private func homeContinuation(in renderer: [String: Any]) -> String? {
        ((renderer["continuations"] as? [[String: Any]])?.first?["nextContinuationData"] as? [String: Any])?["continuation"] as? String
    }
}
