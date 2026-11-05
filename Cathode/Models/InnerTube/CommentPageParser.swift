import Foundation

/// Resolves ordered comment references against entity mutations, keeping reply
/// continuations separate from the containing list's continuation.
nonisolated enum CommentPageParser {
    static func parse(_ json: [String: Any]) -> (comments: [Comment], nextPageToken: String?) {
        let framework = json["frameworkUpdates"] as? [String: Any]
        let batch = framework?["entityBatchUpdate"] as? [String: Any]
        let mutations = batch?["mutations"] as? [[String: Any]] ?? []
        var entities: [String: [String: Any]] = [:]
        var toolbarStates: [String: [String: Any]] = [:]
        for mutation in mutations {
            let payload = mutation["payload"] as? [String: Any]
            if let entity = payload?["commentEntityPayload"] as? [String: Any] {
                if let key = entity["key"] as? String {
                    entities[key] = entity
                }
                if let properties = entity["properties"] as? [String: Any],
                   let id = properties["commentId"] as? String {
                    entities[id] = entity
                }
            }
            if let state = payload?["engagementToolbarStateEntityPayload"] as? [String: Any],
               let key = mutation["entityKey"] as? String {
                toolbarStates[key] = state
            }
        }

        let endpoints = json["onResponseReceivedEndpoints"] as? [[String: Any]] ?? []
        var items: [[String: Any]] = []
        for endpoint in endpoints {
            for key in ["reloadContinuationItemsCommand", "appendContinuationItemsAction", "appendContinuationItemsCommand"] {
                if let command = endpoint[key] as? [String: Any],
                   let contents = command["continuationItems"] as? [[String: Any]] {
                    items.append(contentsOf: contents)
                }
            }
        }

        func parseComment(_ item: [String: Any], depth: Int = 0) -> Comment? {
            guard depth < 50 else { return nil }
            let thread = item["commentThreadRenderer"] as? [String: Any] ?? item
            let replyRenderer = (thread["replies"] as? [String: Any])?["commentRepliesRenderer"] as? [String: Any]
            let replyItems = (replyRenderer?["subThreads"] as? [[String: Any]])
                ?? (replyRenderer?["contents"] as? [[String: Any]]) ?? []
            let replies = replyItems.compactMap { parseComment($0, depth: depth + 1) }
            let replyToken = replyItems.compactMap(continuationToken).first

            if let renderer = (thread["comment"] as? [String: Any])?["commentRenderer"] as? [String: Any]
                ?? thread["commentRenderer"] as? [String: Any],
               let id = renderer["commentId"] as? String {
                let thumbnails = (renderer["authorThumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]]
                return Comment(
                    id: id,
                    author: text(renderer["authorText"]),
                    authorAvatarURL: (thumbnails?.last?["url"] as? String).flatMap(URL.init(string:)),
                    text: text(renderer["contentText"]),
                    likeCount: text(renderer["voteCount"]),
                    publishedTime: text(renderer["publishedTimeText"]),
                    isLiked: renderer["isLiked"] as? Bool ?? false,
                    replies: replies,
                    replyContinuationToken: replyToken
                )
            }

            guard let wrapper = thread["commentViewModel"] as? [String: Any] else { return nil }
            let viewModel = wrapper["commentViewModel"] as? [String: Any] ?? wrapper
            let key = viewModel["commentKey"] as? String ?? ""
            let commentID = viewModel["commentId"] as? String ?? ""
            guard let entity = entities[key] ?? entities[commentID],
                  let properties = entity["properties"] as? [String: Any],
                  let id = properties["commentId"] as? String else { return nil }
            let author = entity["author"] as? [String: Any]
            let toolbar = entity["toolbar"] as? [String: Any]
                ?? properties["toolbarState"] as? [String: Any]
            let stateKey = viewModel["toolbarStateKey"] as? String ?? ""
            let likeState = toolbarStates[stateKey]?["likeState"] as? String
                ?? toolbar?["likeState"] as? String
            return Comment(
                id: id,
                author: author?["displayName"] as? String ?? "",
                authorAvatarURL: (author?["avatarThumbnailUrl"] as? String).flatMap(URL.init(string:)),
                text: (properties["content"] as? [String: Any])?["content"] as? String ?? "",
                likeCount: toolbar?["likeCountNotliked"] as? String ?? "",
                publishedTime: properties["publishedTime"] as? String ?? "",
                isLiked: likeState == "TOOLBAR_LIKE_STATE_LIKED" || likeState == "LIKE_STATE_LIKED",
                replies: replies,
                replyContinuationToken: replyToken
            )
        }

        var seen: Set<String> = []
        let comments = items.compactMap { parseComment($0) }.filter { seen.insert($0.id).inserted }
        return (comments, items.compactMap(continuationToken).last)
    }

    private static func continuationToken(_ item: [String: Any]) -> String? {
        guard let renderer = item["continuationItemRenderer"] as? [String: Any] else { return nil }
        let button = (renderer["button"] as? [String: Any])?["buttonRenderer"] as? [String: Any]
        for endpoint in [renderer["continuationEndpoint"], button?["command"], button?["navigationEndpoint"]] {
            if let endpoint = endpoint as? [String: Any],
               let command = endpoint["continuationCommand"] as? [String: Any],
               let token = command["token"] as? String {
                return token
            }
        }
        return nil
    }

    private static func text(_ value: Any?) -> String {
        guard let value = value as? [String: Any] else { return "" }
        if let simple = value["simpleText"] as? String { return simple }
        return (value["runs"] as? [[String: Any]])?.compactMap { $0["text"] as? String }.joined() ?? ""
    }
}
