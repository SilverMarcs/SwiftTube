import Foundation

// MARK: - Video renderer parsers

extension InnerTubeAPI {

    // MARK: - Flat video group parser

    func parseVideoGroup(from json: [String: Any], title: String?) throws -> VideoGroup {
        var videos: [Video] = []
        var nextPageToken: String? = nil
        // Tracks the approximate watched/published date from section group headers.
        // History (and similar sections) use itemSectionRenderer with a header title
        // like "Today", "Yesterday", "This week" that is the closest available date
        // when the tile metadata lines contain no relative date string.
        var currentSectionDate: Date? = nil

        // Walk the renderer tree to find videoRenderers and continuationItemRenderers.
        // Handles WEB (videoRenderer, richItemRenderer, compactVideoRenderer),
        // WEB grid (gridVideoRenderer), and TVHTML5 tileRenderer (subs/history/home on TV client).
        // Matches Android MediaServiceCore ItemWrapper renderer dispatch order.
        // Iterative tree walk (formerly recursive). A full home-feed renderer tree
        // nests deep enough (~45+ levels) that recursive descent overflowed the small
        // stack of Swift concurrency's cooperative threads, crashing in ___chkstk_darwin.
        // An explicit heap stack keeps traversal depth off the call stack entirely.
        // `.restoreDate` is a sentinel that restores currentSectionDate once an
        // itemSectionRenderer's whole subtree has been processed, mirroring the scoped
        // set/restore the recursive version performed around its walk of `contents`.
        enum WalkItem {
            case node(Any, Int)
            case restoreDate(Date?)
        }
        var stack: [WalkItem] = [.node(json, 0)]
        while let work = stack.popLast() {
            switch work {
            case .restoreDate(let date):
                currentSectionDate = date
                continue
            case .node(let obj, let depth):
                guard depth < 50 else { continue }
                if let dict = obj as? [String: Any] {
                    if ["adSlotRenderer", "adRenderer", "promotedSparklesVideoRenderer", "promotedVideoRenderer"]
                        .contains(where: { dict[$0] != nil }) { continue }
                    // TVHTML5 gridRenderer stores its continuation in
                    // gridRenderer.continuations[0].nextContinuationData.continuation.
                    // Check this independently of the renderer dispatch below so we still
                    // recurse into gridRenderer.items to collect the video tiles.
                    if let continuations = dict["continuations"] as? [[String: Any]],
                       let token = continuations.first
                           .flatMap({ $0["nextContinuationData"] as? [String: Any] })
                           .flatMap({ $0["continuation"] as? String }) {
                        nextPageToken = token
                    }

                    // TVHTML5 History groups tiles under itemSectionRenderer with a date
                    // header ("Today", "Yesterday", "This week", …). Capture that header
                    // and apply it as a fallback publishedAt for tiles with no explicit date.
                    if let sectionRenderer = dict["itemSectionRenderer"] as? [String: Any] {
                        let prevDate = currentSectionDate
                        if let header = sectionRenderer["header"] as? [String: Any] {
                            let headerTitle = extractSectionTitle(from: header)
                            currentSectionDate = headerTitle.flatMap { parseSectionDate($0) }
                        }
                        // Push the restore sentinel first so it runs AFTER the contents
                        // subtree (LIFO), then push the contents to walk next.
                        stack.append(.restoreDate(prevDate))
                        stack.append(.node(sectionRenderer["contents"] as Any, depth + 1))
                        continue
                    }

                    if let renderer = dict["tileRenderer"] as? [String: Any] {
                        // TVHTML5 client (subs, history, home) — Android ItemWrapper.tileRenderer
                        if var v = parseTileRenderer(renderer) {
                            if v.publishedAt == nil { v.publishedAt = currentSectionDate }
                            videos.append(v)
                        }
                    } else if let renderer = dict["videoRenderer"] as? [String: Any] {
                        if let v = parseVideoRenderer(renderer) { videos.append(v) }
                    } else if let renderer = dict["gridVideoRenderer"] as? [String: Any] {
                        if let v = parseVideoRenderer(renderer) { videos.append(v) }
                    } else if let renderer = dict["reelItemRenderer"] as? [String: Any] {
                        if let v = parseReelItemRenderer(renderer) { videos.append(v) }
                    } else if let renderer = dict["richItemRenderer"] as? [String: Any],
                              let content = renderer["content"] as? [String: Any] {
                        if let videoRenderer = content["videoRenderer"] as? [String: Any] {
                            if let v = parseVideoRenderer(videoRenderer) { videos.append(v) }
                        } else if let reelRenderer = content["reelItemRenderer"] as? [String: Any] {
                            if let v = parseReelItemRenderer(reelRenderer) { videos.append(v) }
                        } else if let lockup = content["lockupViewModel"] as? [String: Any] {
                            // WEB home v2: richItemRenderer wraps lockupViewModel
                            if let v = parseLockupViewModel(lockup) { videos.append(v) }
                        } else if let contItem = content["continuationItemRenderer"] as? [String: Any],
                                  let endpoint = contItem["continuationEndpoint"] as? [String: Any],
                                  let command = endpoint["continuationCommand"] as? [String: Any],
                                  let token = command["token"] as? String {
                            // Continuation token nested inside richItemRenderer
                            nextPageToken = token
                        } else {
                            for value in content.values { stack.append(.node(value, depth + 1)) }
                        }
                    } else if let renderer = dict["compactVideoRenderer"] as? [String: Any] {
                        if let v = parseVideoRenderer(renderer) { videos.append(v) }
                    } else if let renderer = dict["playlistVideoRenderer"] as? [String: Any] {
                        // WEB browse response for VL<playlistId> — playlist video items
                        // BUG-012 fix: use parsePlaylistVideoRenderer instead of parseVideoRenderer
                        // so shortBylineText/shortViewCountText fields are read correctly.
                        if let v = parsePlaylistVideoRenderer(renderer) { videos.append(v) }
                    } else if let renderer = dict["lockupViewModel"] as? [String: Any] {
                        // WEB home v2 (LockupItem in Android) — lockupViewModel
                        if let v = parseLockupViewModel(renderer) { videos.append(v) }
                    } else if let contItem = dict["continuationItemRenderer"] as? [String: Any],
                              let endpoint = contItem["continuationEndpoint"] as? [String: Any],
                              let command = endpoint["continuationCommand"] as? [String: Any],
                              let token = command["token"] as? String {
                        nextPageToken = token
                    } else {
                        for value in dict.values { stack.append(.node(value, depth + 1)) }
                    }
                } else if let arr = obj as? [Any] {
                    // Push in reverse so items pop (and their videos append) in source order.
                    for item in arr.reversed() { stack.append(.node(item, depth + 1)) }
                }
            }
        }
        return VideoGroup(title: title, videos: videos, nextPageToken: nextPageToken)
    }

    // MARK: – TVHTML5 tileRenderer parser (Android TileItem methodology)
    // Mirrors: TileItem.getVideoId(), getTitle(), getThumbnails(), getBadgeText(), getChannelId()
    private func parseTileRenderer(_ tile: [String: Any]) -> Video? {
        // Only parse video tiles — require the content type to be explicitly set.
        // Tiles with nil or non-video contentType (e.g. ads with customData/onFirstVisibleCommand)
        // are silently dropped. Android: TILE_CONTENT_TYPE_VIDEO
        // Also accept TILE_CONTENT_TYPE_REEL: FEshorts TVHTML5 response uses this type for
        // Short videos. Silently dropping all REEL tiles is why the Shorts row shows 0 results
        // from the dedicated FEshorts browse (only subs tiles, which are TILE_CONTENT_TYPE_VIDEO,
        // survive).
        let contentType = tile["contentType"] as? String
        switch contentType {
        case "TILE_CONTENT_TYPE_VIDEO", "TILE_CONTENT_TYPE_REEL":
            break // accepted
        default:
            return nil
        }

        // Newer TVHTML5 history/subs responses sometimes nest it under innertubeCommand, or use
        // navigationEndpoint instead of onSelectCommand — try all three paths so regular history
        // videos are not silently dropped (leaving only reelItemRenderer Shorts visible).
        let onSelectCommand = tile["onSelectCommand"] as? [String: Any]
        let navigationEndpoint = tile["navigationEndpoint"] as? [String: Any]
        // videoId resolution order (most to least common in TVHTML5 history/subs responses):
        // 1. onSelectCommand.watchEndpoint.videoId              — classic path
        // 2. onSelectCommand.reelWatchEndpoint.videoId          — Shorts in TV subs/history feed
        // 3. onSelectCommand.innertubeCommand.watchEndpoint.videoId — newer TV variant
        // 4. onSelectCommand.innertubeCommand.reelWatchEndpoint.videoId — nested Shorts variant
        // 5. navigationEndpoint.watchEndpoint.videoId           — another TV variant
        // 6. navigationEndpoint.reelWatchEndpoint.videoId       — nav-level Shorts variant
        // 7. tile.contentId                                     — confirmed by live log: TVHTML5
        //    history tiles with commandExecutorCommand store the id directly here
        let reelWatchEndpoint: [String: Any]? = {
            if let ep = onSelectCommand?["reelWatchEndpoint"] as? [String: Any] { return ep }
            if let inner = onSelectCommand?["innertubeCommand"] as? [String: Any],
               let ep = inner["reelWatchEndpoint"] as? [String: Any] { return ep }
            if let ep = navigationEndpoint?["reelWatchEndpoint"] as? [String: Any] { return ep }
            if let inner = navigationEndpoint?["innertubeCommand"] as? [String: Any],
               let ep = inner["reelWatchEndpoint"] as? [String: Any] { return ep }
            return nil
        }()
        let watchEndpoint: [String: Any]? = {
            if let ep = onSelectCommand?["watchEndpoint"] as? [String: Any] { return ep }
            if let inner = onSelectCommand?["innertubeCommand"] as? [String: Any],
               let ep = inner["watchEndpoint"] as? [String: Any] { return ep }
            if let ep = navigationEndpoint?["watchEndpoint"] as? [String: Any] { return ep }
            return nil
        }()
        guard let videoId = reelWatchEndpoint?["videoId"] as? String
                         ?? watchEndpoint?["videoId"] as? String
                         ?? (tile["contentId"] as? String) else {
            return nil
        }

        // title: metadata.tileMetadataRenderer.title — Android: TileItem.getTitle()
        let tileMetadata = (tile["metadata"] as? [String: Any])?["tileMetadataRenderer"] as? [String: Any]
        let title = (tileMetadata?["title"] as? [String: Any]).flatMap { extractText($0) } ?? ""

        // channelTitle: first line of tileMetadataRenderer.lines[0].lineRenderer.items[0].lineItemRenderer.text
        // Android TileItem.getUserName() = null, but we attempt best-effort extraction from lines
        let channelTitle: String = {
            guard let lines = tileMetadata?["lines"] as? [[String: Any]],
                  let firstLine = lines.first,
                  let lineRenderer = firstLine["lineRenderer"] as? [String: Any],
                  let items = lineRenderer["items"] as? [[String: Any]],
                  let firstItem = items.first,
                  let lineItemRenderer = firstItem["lineItemRenderer"] as? [String: Any],
                  let text = lineItemRenderer["text"] as? [String: Any]
            else { return "" }
            return extractText(text) ?? ""
        }()

        // channelId: watchEndpoint.channelId (primary) or onSelectCommand.browseEndpoint.browseId (secondary)
        // Fallback: extract @handle from onLongPressCommand.showMenuCommand.subtitle.simpleText
        // TV client subtitle format: "ChannelName • @handle" — YouTube browse API accepts @handle as browseId.
        let channelId: String? = {
            if let id = watchEndpoint?["channelId"] as? String { return id }
            if let id = (onSelectCommand?["browseEndpoint"] as? [String: Any])?["browseId"] as? String { return id }
            if let id = channelBrowseID(in: tileMetadata) { return id }
            if let id = channelBrowseID(in: tile["onLongPressCommand"]) { return id }
            guard let showMenu = (tile["onLongPressCommand"] as? [String: Any])?["showMenuCommand"] as? [String: Any],
                  let subtitleText = (showMenu["subtitle"] as? [String: Any])?["simpleText"] as? String,
                  let atIndex = subtitleText.firstIndex(of: "@")
            else { return nil }
            let handle = subtitleText[atIndex...]
                .components(separatedBy: .whitespacesAndNewlines)
                .first
                .map { String($0) }
            return handle
        }()

        // thumbnail: header.tileHeaderRenderer.thumbnail.thumbnails — Android: TileItem.getThumbnails()
        let tileHeader = (tile["header"] as? [String: Any])?["tileHeaderRenderer"] as? [String: Any]
        let thumbnails = (tileHeader?["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]]
        let thumbURL = thumbnails?.last.flatMap { $0["url"] as? String }.flatMap { URL(string: $0) }

        // duration: header.tileHeaderRenderer.thumbnailOverlays[].thumbnailOverlayTimeStatusRenderer.text
        // Android: TileItem.getBadgeText()
        let overlays = tileHeader?["thumbnailOverlays"] as? [[String: Any]]
        let lengthText = overlays?.compactMap {
            ($0["thumbnailOverlayTimeStatusRenderer"] as? [String: Any]).flatMap {
                ($0["text"] as? [String: Any]).flatMap { extractText($0) }
            }
        }.first
        let duration = lengthText.flatMap { parseDuration($0) }

        // percentWatched: thumbnailOverlays[].thumbnailOverlayResumePlaybackRenderer.percentDurationWatched
        // (same path as WEB, used for watch-again resume)
        let watchProgress: Double? = overlays?.compactMap {
            ($0["thumbnailOverlayResumePlaybackRenderer"] as? [String: Any])
                .flatMap { $0["percentDurationWatched"] as? Double }
        }.first.map { $0 / 100.0 }

        // isLive: thumbnailOverlay style == "LIVE" — Android: TileItem.isLive()
        let isLive = overlays?.contains {
            ($0["thumbnailOverlayTimeStatusRenderer"] as? [String: Any])?["style"] as? String == "LIVE"
        } ?? false

        // isShorts: style == "TILE_STYLE_YTLR_SHORTS" — Android: TileItem.isShorts()
        // Secondary signals (in priority order):
        //  • reelWatchEndpoint present on onSelectCommand/navigationEndpoint — definitive for Shorts
        //    tiles that carry neither TILE_STYLE_YTLR_SHORTS nor the overlay SHORTS style.
        //  • thumbnailOverlayTimeStatusRenderer.style == "SHORTS" — older TV subs feed fallback.
        //  • ustreamerConfig == "GgIIBQ==" — encodes proto(field3{field1:5}); value 5 is YouTube's
        //    CONTENT_TYPE_SHORTS hint embedded in the watchEndpoint. Observed on Shorts tiles that
        //    carry none of the other signals (TILE_STYLE_YTLR_DEFAULT, watchEndpoint not reel,
        //    landscape thumbnail). Regular videos carry value 1 ("GgIIAQ==") or omit the field.
        //  • Portrait thumbnail (height > width) — Shorts have 9:16 thumbnails; news/sports clips
        //    are always landscape 16:9, so this signal has zero false-positive risk for those.
        let isVerticalThumbnail = thumbnails?.contains {
            let w = ($0["width"] as? Int) ?? 0
            let h = ($0["height"] as? Int) ?? 0
            return h > w && w > 0
        } ?? false

        let ustreamerConfig = watchEndpoint?["ustreamerConfig"] as? String
        // GgIIBQ== encodes CONTENT_TYPE_SHORTS, but YouTube also attaches it to long-form
        // videos that appear in Shorts-adjacent shelves (subscription Shorts shelf, history,
        // home recommendations). Guard with a 180 s ceiling — the maximum YouTube Shorts
        // length — so only genuine Shorts are matched. When duration is unknown (nil),
        // default to trusting the signal.
        // Live streams also carry GgIIBQ== and have nil duration (text is "LIVE") — exclude them.
        let isUstreamerShorts = ustreamerConfig == "GgIIBQ==" && !isLive && (duration.map { $0 <= 180 } ?? true)

        let isShort = (tile["style"] as? String) == "TILE_STYLE_YTLR_SHORTS"
            || reelWatchEndpoint != nil
            || overlays?.contains {
                ($0["thumbnailOverlayTimeStatusRenderer"] as? [String: Any])?["style"] as? String == "SHORTS"
            } ?? false
            || isUstreamerShorts
            || isVerticalThumbnail

        // publishedAt: best-effort from tileMetadata lines (second line may contain "2 years ago")
        let publishedAt: Date? = {
            guard let lines = tileMetadata?["lines"] as? [[String: Any]], lines.count > 1 else { return nil }
            for line in lines.dropFirst() {
                guard let items = (line["lineRenderer"] as? [String: Any])?["items"] as? [[String: Any]] else { continue }
                for item in items {
                    guard let text = (item["lineItemRenderer"] as? [String: Any])?["text"] as? [String: Any],
                          let str = extractText(text)
                    else { continue }
                    if let date = parseRelativeDate(str) { return date }
                }
            }
            return nil
        }()

        return Video(
            id: videoId,
            title: title,
            channelTitle: channelTitle,
            channelId: channelId,
            channelAvatarURL: channelAvatarURL(in: tileMetadata),
            duration: duration,
            viewCount: {
                // BUG-011 fix: extract viewCount from tileMetadata lines instead of hardcoding nil.
                // The second line (index 1) typically contains "N views" or compact "1.2K views".
                guard let lines = tileMetadata?["lines"] as? [[String: Any]] else { return nil }
                for line in lines.dropFirst() {
                    guard let items = (line["lineRenderer"] as? [String: Any])?["items"] as? [[String: Any]] else { continue }
                    for item in items {
                        guard let text = (item["lineItemRenderer"] as? [String: Any])?["text"] as? [String: Any],
                              let str = extractText(text)
                        else { continue }
                        if let count = extractNumber(str) { return count }
                    }
                }
                return nil
            }(),
            publishedAt: publishedAt,
            isLive: isLive,
            isShort: isShort,
            watchProgress: watchProgress,
            badges: []
        )
    }

    // MARK: – WEB / TV lockupViewModel parser (Android LockupItem methodology)
    // Mirrors: LockupItem.getVideoId(), getTitle(), getThumbnails() in CommonHelper.kt
    private func parseLockupViewModel(_ lockup: [String: Any]) -> Video? {
        // videoId: rendererContext.commandContext.onTap.innertubeCommand.{watchEndpoint|reelWatchEndpoint}.videoId
        // Shorts use reelWatchEndpoint; regular videos use watchEndpoint.
        let rendererContext = lockup["rendererContext"] as? [String: Any]
        let commandContext = rendererContext?["commandContext"] as? [String: Any] ?? [:]
        let onTap = commandContext["onTap"] as? [String: Any]
        let innertubeCommand = onTap?["innertubeCommand"] as? [String: Any] ?? [:]

        let reelEndpoint = innertubeCommand["reelWatchEndpoint"] as? [String: Any]
        let watchEndpoint = innertubeCommand["watchEndpoint"] as? [String: Any]
        if let type = lockup["contentType"] as? String,
           type != "LOCKUP_CONTENT_TYPE_VIDEO", reelEndpoint == nil { return nil }
        guard let videoId = reelEndpoint?["videoId"] as? String
                          ?? watchEndpoint?["videoId"] as? String
                          ?? (lockup["contentType"] as? String == "LOCKUP_CONTENT_TYPE_VIDEO"
                              ? lockup["contentId"] as? String : nil) else { return nil }
        let isShort = reelEndpoint != nil

        // title: metadata.lockupMetadataViewModel.title
        // The field may be a TextViewModel ({"content": "…"}) in newer API responses,
        // or a legacy runs/simpleText dict handled by extractText.
        let lockupMeta = (lockup["metadata"] as? [String: Any])?["lockupMetadataViewModel"] as? [String: Any]
        let title: String = {
            guard let titleDict = lockupMeta?["title"] as? [String: Any] else { return "" }
            return titleDict["content"] as? String ?? extractText(titleDict) ?? ""
        }()

        // channelTitle + channelId: metadata.lockupMetadataViewModel.metadata.contentMetadataViewModel.metadataRows
        // The first row typically contains the channel name with a browseEndpoint for the channel.
        let metaContentVM = (lockupMeta?["metadata"] as? [String: Any])?["contentMetadataViewModel"] as? [String: Any]
        let metaRows = metaContentVM?["metadataRows"] as? [[String: Any]] ?? []

        let channelTitle: String = {
            guard let firstRow = metaRows.first,
                  let parts = firstRow["metadataParts"] as? [[String: Any]],
                  let firstPart = parts.first,
                  let text = firstPart["text"] as? [String: Any]
            else { return "" }
            return text["content"] as? String ?? extractText(text) ?? ""
        }()

        // WEB links the creator through the avatar or text command runs; TV
        // commonly supplies the channel only in the long-press menu.
        let channelId: String? = (watchEndpoint?["channelId"] as? String)
            ?? (reelEndpoint?["channelId"] as? String)
            ?? channelBrowseID(in: lockupMeta?["image"])
            ?? channelBrowseID(in: metaRows)
            ?? channelBrowseID(in: commandContext["onLongPress"])
            ?? channelBrowseID(in: lockupMeta?["menuButton"])

        // thumbnail: contentImage.thumbnailViewModel.image.thumbnails
        let thumbVM = (lockup["contentImage"] as? [String: Any])?["thumbnailViewModel"] as? [String: Any]
        let thumbnails = (thumbVM?["image"] as? [String: Any])?["thumbnails"] as? [[String: Any]]
        let thumbURL = thumbnails?.last.flatMap { $0["url"] as? String }.flatMap { URL(string: $0) }

        let publishedAt: Date? = {
            for row in metaRows.dropFirst() {
                guard let parts = row["metadataParts"] as? [[String: Any]] else { continue }
                for part in parts {
                    guard let text = part["text"] as? [String: Any],
                          let str = text["content"] as? String ?? extractText(text)
                    else { continue }
                    if let date = parseRelativeDate(str) { return date }
                }
            }
            return nil
        }()

        return Video(
            id: videoId, title: title, channelTitle: channelTitle, channelId: channelId,
            channelAvatarURL: channelAvatarURL(in: lockupMeta?["image"]),
            viewCount: {
                // BUG-011 fix: extract viewCount from contentMetadataViewModel metadataRows.
                // Row index 1 (second row) often contains "N views" or compact count.
                for row in metaRows.dropFirst() {
                    guard let parts = row["metadataParts"] as? [[String: Any]] else { continue }
                    for part in parts {
                        guard let text = part["text"] as? [String: Any],
                              let str = text["content"] as? String ?? extractText(text)
                        else { continue }
                        if let count = extractNumber(str) { return count }
                    }
                }
                return nil
            }(),
            publishedAt: publishedAt,
            isLive: false, isShort: isShort, badges: []
        )
    }

    // MARK: – Shorts reelItemRenderer parser
    private func parseReelItemRenderer(_ r: [String: Any]) -> Video? {
        guard let videoId = r["videoId"] as? String else { return nil }
        let title = (r["headline"] as? [String: Any]).flatMap { extractText($0) } ?? ""
        let thumbnails = (r["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]]
        let thumbURL = thumbnails?.last.flatMap { $0["url"] as? String }.flatMap { URL(string: $0) }

        // channelTitle: ownerText or shortBylineText
        let channelTitle: String = (r["ownerText"] as? [String: Any]).flatMap { extractText($0) }
            ?? (r["shortBylineText"] as? [String: Any]).flatMap { extractText($0) }
            ?? ""

        // channelId: navigationEndpoint.reelWatchEndpoint.channelId (primary)
        // or ownerText/shortBylineText runs[0].navigationEndpoint.browseEndpoint.browseId (fallback)
        let channelId: String? = {
            if let channelId = (r["navigationEndpoint"] as? [String: Any])
                .flatMap({ ($0["reelWatchEndpoint"] as? [String: Any])?["channelId"] as? String }) {
                return channelId
            }
            let sourceKey = r["ownerText"] != nil ? "ownerText" : "shortBylineText"
            guard let runs = (r[sourceKey] as? [String: Any])?["runs"] as? [[String: Any]],
                  let first = runs.first,
                  let nav = first["navigationEndpoint"] as? [String: Any],
                  let browse = nav["browseEndpoint"] as? [String: Any]
            else { return nil }
            return browse["browseId"] as? String
        }()

        return Video(
            id: videoId, title: title, channelTitle: channelTitle, channelId: channelId,
            viewCount: {
                // BUG-011 fix: extract viewCount from viewCountText (runs or simpleText).
                let vcText = (r["viewCountText"] as? [String: Any]).flatMap { extractText($0) }
                return vcText.flatMap { extractNumber($0) }
            }(),
            isLive: false, isShort: true, hasPortraitThumbnail: true, badges: []
        )
    }

    // MARK: – WEB videoRenderer parser
    func parseVideoRenderer(_ r: [String: Any]) -> Video? {
        guard let videoId = r["videoId"] as? String else { return nil }
        let title = (r["title"] as? [String: Any]).flatMap { extractText($0) }
            ?? (r["headline"] as? [String: Any]).flatMap { extractText($0) }
            ?? ""
        let channelTitle = (r["ownerText"] as? [String: Any]).flatMap { extractText($0) }
            ?? (r["shortBylineText"] as? [String: Any]).flatMap { extractText($0) }
            ?? ""

        // channelId: ownerText (videoRenderer) or shortBylineText (gridVideoRenderer)
        let channelId = channelBrowseID(in: r["ownerText"])
            ?? channelBrowseID(in: r["shortBylineText"])
            ?? channelBrowseID(in: r["longBylineText"])
            ?? channelBrowseID(in: r["channelThumbnailSupportedRenderers"])
            ?? channelBrowseID(in: r["menu"])

        let thumbnails = (r["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]]
        let thumbURL = thumbnails?.last.flatMap { $0["url"] as? String }.flatMap { URL(string: $0) }

        // duration: lengthText (videoRenderer) or thumbnailOverlays[N].thumbnailOverlayTimeStatusRenderer.text (gridVideoRenderer)
        let lengthText: String? = (r["lengthText"] as? [String: Any]).flatMap { extractText($0) }
            ?? (r["thumbnailOverlays"] as? [[String: Any]])?
                .compactMap { ($0["thumbnailOverlayTimeStatusRenderer"] as? [String: Any])?["text"] as? [String: Any] }
                .first.flatMap { extractText($0) }
        let duration = lengthText.flatMap { parseDuration($0) }

        let viewCountText = (r["viewCountText"] as? [String: Any]).flatMap { extractText($0) }
            // BUG-014 fix: fall back to shortViewCountText when viewCountText is absent (some locales/auth configs).
            ?? (r["shortViewCountText"] as? [String: Any]).flatMap { extractText($0) }
        let viewCount = viewCountText.flatMap { extractNumber($0) }
            // Further fallback: direct integer field (rare, but present in some compact API responses).
            ?? r["viewCount"] as? Int

        let isLive = (r["badges"] as? [[String: Any]])?.contains {
            (($0["metadataBadgeRenderer"] as? [String: Any])?["style"] as? String) == "BADGE_STYLE_TYPE_LIVE_NOW"
        } ?? false

        let isShort: Bool = {
            // Primary signal: reelWatchEndpoint in navigationEndpoint (home, search, most feeds)
            if let nav = r["navigationEndpoint"] as? [String: Any], nav["reelWatchEndpoint"] != nil {
                return true
            }
            // Secondary signal: thumbnailOverlayTimeStatusRenderer.style == "SHORTS"
            // (subscriptions feed often omits reelWatchEndpoint and uses this style instead).
            // Guard with duration ≤ 180 s: regular videos can appear in Shorts-adjacent shelves
            // with this overlay style, causing false positives. Duration validation prevents
            // misclassification of videos like vkUokV3Xwp8. Mirrors the guard in parseTileRenderer.
            let hasShortOverlay = (r["thumbnailOverlays"] as? [[String: Any]])?.contains {
                ($0["thumbnailOverlayTimeStatusRenderer"] as? [String: Any])?["style"] as? String == "SHORTS"
            } ?? false
            if hasShortOverlay && (duration.map { $0 <= 180 } ?? true) { return true }
            // Tertiary signal: ustreamerConfig == "GgIIBQ==" — mirrors parseTileRenderer.
            // Catches compactVideoRenderer Short tiles in TV subs/history feeds that omit both
            // reelWatchEndpoint and the overlay style.
            let watchEndpoint = (r["navigationEndpoint"] as? [String: Any])?["watchEndpoint"] as? [String: Any]
            let ustreamerConfig = watchEndpoint?["ustreamerConfig"] as? String
            if ustreamerConfig == "GgIIBQ==" && (duration.map { $0 <= 180 } ?? true) { return true }
            // Quaternary signal: vertical thumbnail (height > width) — another parseTileRenderer mirror.
            let thumbnails = (r["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]]
            let isVerticalThumbnail = thumbnails?.contains {
                let w = ($0["width"] as? Int) ?? 0
                let h = ($0["height"] as? Int) ?? 0
                return h > w && w > 0
            } ?? false
            return isVerticalThumbnail
        }()
        let badges = (r["badges"] as? [[String: Any]])?.compactMap {
            ($0["metadataBadgeRenderer"] as? [String: Any])?["label"] as? String
        } ?? []

        let watchProgress: Double? = (r["thumbnailOverlays"] as? [[String: Any]])?
            .compactMap { ($0["thumbnailOverlayResumePlaybackRenderer"] as? [String: Any])
                .flatMap { $0["percentDurationWatched"] as? Double } }
            .first.map { $0 / 100.0 }

        // Parse feed feedback tokens keyed by icon type from the video's menuRenderer.
        // All three actions share the /feedback endpoint — only the token differs.
        let feedbackTokens: [String: String] = {
            guard let menu = r["menu"] as? [String: Any],
                  let mr = menu["menuRenderer"] as? [String: Any],
                  let items = mr["items"] as? [[String: Any]]
            else { return [:] }
            var result: [String: String] = [:]
            for item in items {
                guard let svc = item["menuServiceItemRenderer"] as? [String: Any],
                      let endpoint = svc["serviceEndpoint"] as? [String: Any],
                      let token = (endpoint["feedbackEndpoint"] as? [String: Any])?["feedbackToken"] as? String,
                      let iconType = (svc["icon"] as? [String: Any])?["iconType"] as? String
                else { continue }
                result[iconType] = token
            }
            return result
        }()

        let publishedAt: Date? = (r["publishedTimeText"] as? [String: Any])
            .flatMap { extractText($0) }
            .flatMap { parseRelativeDate($0) }

        return Video(
            id: videoId,
            title: title,
            channelTitle: channelTitle,
            channelId: channelId,
            channelAvatarURL: channelAvatarURL(in: r["channelThumbnailSupportedRenderers"]),
            duration: duration,
            viewCount: viewCount,
            publishedAt: publishedAt,
            isLive: isLive,
            isShort: isShort,
            watchProgress: watchProgress,
            badges: badges,
            notInterestedToken: feedbackTokens["NOT_INTERESTED"],
            dontLikeToken: feedbackTokens["DISLIKE"],
            hideChannelToken: feedbackTokens["BLOCK_CHANNEL"]
        )
    }

    // MARK: – WEB playlistVideoRenderer parser (BUG-012 fix)
    // Playlist video items use shortBylineText/shortViewCountText instead of
    // ownerText/viewCountText which parseVideoRenderer expects.
    private func parsePlaylistVideoRenderer(_ r: [String: Any]) -> Video? {
        guard let videoId = r["videoId"] as? String else { return nil }
        let title = (r["title"] as? [String: Any]).flatMap { extractText($0) } ?? ""

        // channelTitle: shortBylineText preferred; ownerText as fallback
        let channelTitle = (r["shortBylineText"] as? [String: Any]).flatMap { extractText($0) }
            ?? (r["ownerText"] as? [String: Any]).flatMap { extractText($0) }
            ?? ""

        // channelId: from shortBylineText or ownerText runs[0].navigationEndpoint.browseEndpoint.browseId
        let channelId: String? = {
            let sourceKey = r["shortBylineText"] != nil ? "shortBylineText" : "ownerText"
            guard let runs = (r[sourceKey] as? [String: Any])?["runs"] as? [[String: Any]],
                  let first = runs.first,
                  let nav = first["navigationEndpoint"] as? [String: Any],
                  let browse = nav["browseEndpoint"] as? [String: Any]
            else { return nil }
            return browse["browseId"] as? String
        }()

        let thumbnails = (r["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]]
        let thumbURL = thumbnails?.last.flatMap { $0["url"] as? String }.flatMap { URL(string: $0) }

        let lengthText = (r["lengthText"] as? [String: Any]).flatMap { extractText($0) }
        let duration = lengthText.flatMap { parseDuration($0) }

        // viewCount: shortViewCountText preferred; viewCountText as fallback; direct int last
        let viewCountText = (r["shortViewCountText"] as? [String: Any]).flatMap { extractText($0) }
            ?? (r["viewCountText"] as? [String: Any]).flatMap { extractText($0) }
        let viewCount = viewCountText.flatMap { extractNumber($0) } ?? r["viewCount"] as? Int

        let watchProgress: Double? = (r["thumbnailOverlays"] as? [[String: Any]])?
            .compactMap { ($0["thumbnailOverlayResumePlaybackRenderer"] as? [String: Any])
                .flatMap { $0["percentDurationWatched"] as? Double } }
            .first.map { $0 / 100.0 }

        let publishedAt: Date? = (r["publishedTimeText"] as? [String: Any])
            .flatMap { extractText($0) }
            .flatMap { parseRelativeDate($0) }

        return Video(
            id: videoId,
            title: title,
            channelTitle: channelTitle,
            channelId: channelId,
            duration: duration,
            viewCount: viewCount,
            publishedAt: publishedAt,
            isLive: false,
            isShort: false,
            watchProgress: watchProgress,
            badges: []
        )
    }
}

