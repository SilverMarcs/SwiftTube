import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Player endpoint (metadata)

extension InnerTubeAPI {

    /// Fetches video metadata (title, author, description, duration, view count)
    /// from the InnerTube `/player` endpoint via the iOS client.
    ///
    /// Stream extraction no longer lives here — playback resolves on-device via
    /// YouTubeKit in `StreamResolver`. This call survives only as a metadata
    /// source for description backfill and deep-link `Video` construction.
    public func fetchPlayerInfo(videoId: String) async throws -> PlayerInfo {
        var body = makeBody(client: iosClientContext)
        body["videoId"] = videoId
        body["racyCheckOk"] = true
        body["contentCheckOk"] = true
        let data = try await postPlayer(body: body)
        return try parsePlayerInfo(from: data, videoId: videoId)
    }

    // MARK: - Private player helpers

    private func parsePlayerInfo(from json: [String: Any], videoId: String) throws -> PlayerInfo {
        let videoDetails = json["videoDetails"] as? [String: Any]
        let title = videoDetails?["title"] as? String ?? ""
        let channelTitle = videoDetails?["author"] as? String ?? ""
        let description = videoDetails?["shortDescription"] as? String
        let durationStr = videoDetails?["lengthSeconds"] as? String
        let duration = durationStr.flatMap { Double($0) }
        let isLive = videoDetails?["isLiveContent"] as? Bool ?? false
        let viewCount = (videoDetails?["viewCount"] as? String).flatMap { Int($0) }

        let streamingData = json["streamingData"] as? [String: Any]
        let playabilityDict  = json["playabilityStatus"] as? [String: Any]
        let playabilityStatus = playabilityDict?["status"] as? String ?? "unknown"
        let playabilityReason = playabilityDict?["reason"] as? String
            ?? (playabilityDict?["errorScreen"] as? [String: Any])
                .flatMap { ($0["playerErrorMessageRenderer"] as? [String: Any])?["subreason"] as? [String: Any] }
                .flatMap { extractText($0) }
        // Fail early for definitely-unplayable videos so callers don't waste work on
        // related/SponsorBlock fetches. Mirrors Android playabilityStatus check.
        if streamingData == nil, playabilityStatus != "OK" {
            let reason = playabilityReason ?? "This video is unavailable (\(playabilityStatus))"
            // Check for IP-block signals before throwing the generic unavailable error.
            // These keywords indicate YouTube is rejecting the request based on the source
            // IP (VPN/proxy/shared datacenter). Throwing a distinct error type lets callers
            // short-circuit the retry chain and show a targeted message.
            let lower = reason.lowercased()
            let ipBlockKeywords = ["your ip", "ip address", "vpn", "proxy", "bot", "sign in to confirm"]
            if ipBlockKeywords.contains(where: { lower.contains($0) }) {
                throw ITAPIError.ipBlocked(reason)
            }
            throw ITAPIError.unavailable(reason)
        }

        let video = Video(
            id: videoId,
            title: title,
            channelTitle: channelTitle,
            description: description,
            duration: duration,
            viewCount: viewCount,
            isLive: isLive
        )
        return PlayerInfo(video: video)
    }
}
