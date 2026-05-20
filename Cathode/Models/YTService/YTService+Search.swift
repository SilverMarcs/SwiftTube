//
//  YTService+Search.swift
//  Cathode
//
//  InnerTube-backed search. The InnerTube `search` endpoint returns a single
//  mixed `VideoGroup`. Channel-style results parse out as ITVideo entries with
//  no `duration` and an `id` that starts with "UC" (the channelId), so we use
//  that signal to split them into the `channels` bucket Cathode expects.
//

import Foundation

extension YTService {
    static func search(query: String) async throws -> SearchResults {
        let group = try await InnerTubeAPI.shared.search(query: query)

        var videos: [Video] = []
        var channels: [Channel] = []
        var seenChannelIds = Set<String>()

        for it in group.videos {
            if isChannelEntry(it) {
                let channelId = it.channelId ?? it.id
                guard !channelId.isEmpty, !seenChannelIds.contains(channelId) else { continue }
                seenChannelIds.insert(channelId)
                channels.append(
                    Channel(
                        id: channelId,
                        title: it.channelTitle.isEmpty ? it.title : it.channelTitle,
                        channelDescription: it.description ?? "",
                        thumbnailURL: it.thumbnailURL?.absoluteString ?? "",
                        viewCount: 0,
                        subscriberCount: 0
                    )
                )
            } else {
                videos.append(Video(it))
            }
        }
        return SearchResults(videos: videos, channels: channels)
    }

    /// Heuristic for "is this ITVideo really a channel result?".
    /// Channel renderers come back with the channelId in the `id` slot and no
    /// duration; ordinary video renderers always carry an 11-char videoId.
    private static func isChannelEntry(_ it: ITVideo) -> Bool {
        it.id.hasPrefix("UC") && it.id.count > 11 && it.duration == nil
    }
}

struct SearchResults {
    let videos: [Video]
    let channels: [Channel]

    var isEmpty: Bool {
        videos.isEmpty && channels.isEmpty
    }
}
