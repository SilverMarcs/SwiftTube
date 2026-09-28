import Foundation

/// The embedded player binds its playback context to the page's Referer.
/// Use this same URL when fetching configuration and when posting /player.
/// Mirrors yt-dlp's embedded configuration and encryptedHostFlags handling;
/// Safari HLS support: https://github.com/yt-dlp/yt-dlp/pull/17684.
nonisolated struct YouTubeEmbeddedPlayerConfiguration: Sendable {
    static let embedURL = "https://apps.apple.com/app/id6765878641"

    struct ThirdParty: Codable, Sendable {
        struct EmbeddedPlayerContext: Codable, Sendable {
            let embeddedPlayerEncryptedContext: String
            let ancestorOriginsSupported: Bool?
        }

        var embedUrl: String?
        let embeddedPlayerContext: EmbeddedPlayerContext
    }

    let clientVersion: String
    let visitorData: String
    let encryptedHostFlags: String
    let thirdParty: ThirdParty

    private struct PageConfiguration: Decodable {
        struct Context: Decodable {
            struct Client: Decodable {
                let clientName: String
                let clientVersion: String
                let visitorData: String
            }
            let client: Client
            let thirdParty: ThirdParty
        }
        struct Player: Decodable {
            let encryptedHostFlags: String?
        }
        let INNERTUBE_CONTEXT: Context
        let WEB_PLAYER_CONTEXT_CONFIGS: [String: Player]
    }

    static func parse(_ html: String) throws -> Self {
        let expression = try NSRegularExpression(pattern: #"ytcfg\.set\s*\(\s*\{"#)
        for match in expression.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
            guard let range = Range(match.range, in: html),
                  let data = jsonObject(in: html[html.index(before: range.upperBound)...]),
                  let page = try? JSONDecoder().decode(PageConfiguration.self, from: data),
                  page.INNERTUBE_CONTEXT.client.clientName == "WEB_EMBEDDED_PLAYER",
                  let player = page.WEB_PLAYER_CONTEXT_CONFIGS["WEB_PLAYER_CONTEXT_CONFIG_ID_EMBEDDED_PLAYER"],
                  let encryptedHostFlags = player.encryptedHostFlags, !encryptedHostFlags.isEmpty,
                  !page.INNERTUBE_CONTEXT.client.clientVersion.isEmpty,
                  !page.INNERTUBE_CONTEXT.client.visitorData.isEmpty,
                  !page.INNERTUBE_CONTEXT.thirdParty.embeddedPlayerContext.embeddedPlayerEncryptedContext.isEmpty
            else { continue }
            var thirdParty = page.INNERTUBE_CONTEXT.thirdParty
            thirdParty.embedUrl = embedURL
            return Self(
                clientVersion: page.INNERTUBE_CONTEXT.client.clientVersion,
                visitorData: page.INNERTUBE_CONTEXT.client.visitorData,
                encryptedHostFlags: encryptedHostFlags,
                thirdParty: thirdParty
            )
        }
        throw StreamExtractionError.invalidResponse
    }

    private static func jsonObject(in text: Substring) -> Data? {
        var depth = 0
        var inString = false
        var escaped = false
        for index in text.indices {
            let character = text[index]
            if inString {
                if escaped { escaped = false }
                else if character == "\\" { escaped = true }
                else if character == "\"" { inString = false }
            } else {
                switch character {
                case "\"": inString = true
                case "{": depth += 1
                case "}":
                    depth -= 1
                    if depth == 0 { return Data(text[...index].utf8) }
                default: break
                }
            }
        }
        return nil
    }
}
