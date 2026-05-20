//
//  YTService+Video.swift
//  Cathode
//
//  InnerTube-backed video detail/enrichment helpers.
//

import Foundation

extension YTService {
    /// Enriches a single Video in place with duration / view / like counts pulled
    /// from InnerTube's `/next` endpoint (no `/player` call — we don't need streams here).
    static func fetchVideoDetails(for video: inout Video) async throws {
        let it = try await fetchEnrichedITVideo(videoId: video.id)
        if let d = it.duration { video.duration = Int(d) }
        if let vc = it.viewCount { video.viewCount = String(vc) }
        // ITVideo doesn't currently expose a likeCount field — leave unchanged.
        // isShort heuristic: re-derive from duration when we now have one.
        if let d = video.duration, d > 0, d <= 60 {
            video.isShort = true
        }
    }

    /// Batched video-detail fetch. InnerTube has no batch endpoint, so we fan out
    /// to bounded-concurrency TaskGroup workers and merge results back into the
    /// caller's array. Bounded at 6 concurrent fetches to stay under YouTube's
    /// per-IP rate-limit ceiling.
    static func fetchVideoDetails(for videos: inout [Video]) async throws {
        let limitedCount = min(videos.count, 50)
        guard limitedCount > 0 else { return }
        let ids = videos.prefix(limitedCount).map(\.id)

        let updates: [String: ITVideo] = await withTaskGroup(
            of: (String, ITVideo?).self,
            returning: [String: ITVideo].self
        ) { group in
            let maxConcurrent = 6
            var inFlight = 0
            var iterator = ids.makeIterator()

            func addNext() {
                guard let id = iterator.next() else { return }
                inFlight += 1
                group.addTask {
                    do {
                        return (id, try await fetchEnrichedITVideo(videoId: id))
                    } catch {
                        return (id, nil)
                    }
                }
            }
            for _ in 0..<min(maxConcurrent, ids.count) { addNext() }

            var collected: [String: ITVideo] = [:]
            while inFlight > 0 {
                if let (id, it) = await group.next() {
                    inFlight -= 1
                    if let it = it { collected[id] = it }
                    addNext()
                }
            }
            return collected
        }

        for i in videos.indices {
            guard let it = updates[videos[i].id] else { continue }
            if let d = it.duration { videos[i].duration = Int(d) }
            if let vc = it.viewCount { videos[i].viewCount = String(vc) }
            if let d = videos[i].duration, d > 0, d <= 60 {
                videos[i].isShort = true
            }
        }
    }

    /// Fetches a single Video by id, using InnerTube. Pairs the video with a
    /// Channel — preferring a saved/cached one if present, else falling back to
    /// a lightweight stub built from the ITVideo's own channel fields.
    static func fetchVideo(byId id: String) async throws -> Video {
        let it = try await fetchEnrichedITVideo(videoId: id)
        let channel: Channel
        if let channelId = it.channelId,
           let saved = CloudStoreManager.shared.savedChannels.first(where: { $0.id == channelId }) {
            channel = saved
        } else if let channelId = it.channelId, !channelId.isEmpty {
            // Try a full channel fetch; if it fails, fall back to a stub from ITVideo.
            if let fetched = try? await YTService.fetchChannel(byId: channelId) {
                channel = fetched
            } else {
                channel = Channel(
                    id: channelId,
                    title: it.channelTitle,
                    channelDescription: "",
                    thumbnailURL: ""
                )
            }
        } else {
            channel = Channel(
                id: "",
                title: it.channelTitle,
                channelDescription: "",
                thumbnailURL: ""
            )
        }
        return Video(it, channel: channel)
    }

    // MARK: - Private

    /// Combines `/next` (metadata + related) — we need duration/viewCount which
    /// the watch-page `/next` response carries on the primary video. Falls back
    /// to a stub ITVideo built from `videoId` when nothing usable is parsed.
    ///
    /// Implementation note: SmartTube's InnerTubeAPI doesn't expose a one-shot
    /// "fetch a single video's metadata" call. The closest fit is `fetchPlayerInfo`,
    /// whose `PlayerInfo.video` carries duration/viewCount populated from the
    /// `videoDetails` block in the /player response.
    fileprivate static func fetchEnrichedITVideo(videoId: String) async throws -> ITVideo {
        let info = try await InnerTubeAPI.shared.fetchPlayerInfo(videoId: videoId)
        return info.video
    }
}
