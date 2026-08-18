import Foundation

nonisolated struct FMP4Segment: Sendable {
    let offset: Int      // absolute byte offset in file
    let size: Int        // bytes
    let duration: Double // seconds
}

nonisolated struct FMP4Info: Sendable {
    let initSize: Int            // bytes from start that comprise ftyp+moov (HLS EXT-X-MAP range)
    let segments: [FMP4Segment]
    let totalDuration: Double
}

nonisolated enum FMP4ParseError: Error, CustomStringConvertible {
    case rangeNotSupported(statusCode: Int?)
    case truncated
    case missingSidx
    case unsupportedSidxVersion

    var description: String {
        switch self {
        case .rangeNotSupported(let statusCode):
            "rangeNotSupported(statusCode: \(statusCode.map(String.init) ?? "none"))"
        case .truncated:
            "truncated"
        case .missingSidx:
            "missingSidx"
        case .unsupportedSidxVersion:
            "unsupportedSidxVersion"
        }
    }
}

nonisolated enum FMP4Parser {

    /// Fetches a prefix of the file via HTTP Range and parses ftyp/moov/sidx.
    static func parse(
        url: URL,
        requestHeaders: [String: String] = [:],
        prefixBytes: Int = 1_048_576
    ) async throws -> FMP4Info {
        var req = URLRequest(url: url)
        req.httpShouldHandleCookies = false
        req.setValue("bytes=0-\(prefixBytes - 1)", forHTTPHeaderField: "Range")
        for (header, value) in requestHeaders {
            req.setValue(value, forHTTPHeaderField: header)
        }
        // Fresh googlevideo URLs can 403 exactly once while the edge warms
        // authorization; the identical request succeeds ~2s later. Retry the
        // request itself — failing here makes the resolver re-extract, which
        // mints another cold URL and loops forever on first-request 403s.
        var lastStatusCode: Int?
        for attempt in 0..<3 {
            if attempt > 0 { try await Task.sleep(for: .seconds(2)) }
            let (data, response) = try await YouTubeMediaTransport.session.data(for: req)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode)
            else {
                lastStatusCode = (response as? HTTPURLResponse)?.statusCode
                continue
            }
            return try parseBoxes(data: data)
        }
        throw FMP4ParseError.rangeNotSupported(statusCode: lastStatusCode)
    }

    /// Checks byte offsets beyond the one-megabyte metadata prefix. YouTube's
    /// selective GVS proof-token enforcement can allow that prefix and then
    /// return 403 for the first media range that crosses it, causing playback
    /// to die roughly a minute later despite a successful initial preflight.
    static func preflightMediaAccess(
        url: URL,
        requestHeaders: [String: String],
        info: FMP4Info
    ) async throws {
        guard let finalSegment = info.segments.last,
              finalSegment.offset <= Int.max - finalSegment.size
        else { return }
        let finalByteOffset = finalSegment.offset + finalSegment.size - 1
        guard finalByteOffset >= 1_048_576 else { return }

        let offsets = Set([
            1_048_576,
            finalByteOffset / 4 * 3,
        ]).sorted()
        let session = YouTubeMediaTransport.makePlaybackSession()
        defer { session.invalidateAndCancel() }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for offset in offsets where offset <= finalByteOffset {
                group.addTask {
                    var request = URLRequest(url: url)
                    request.httpShouldHandleCookies = false
                    request.setValue(
                        "bytes=\(offset)-\(offset)",
                        forHTTPHeaderField: "Range"
                    )
                    request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
                    for (header, value) in requestHeaders {
                        request.setValue(value, forHTTPHeaderField: header)
                    }
                    let (data, response) = try await session.data(for: request)
                    guard let http = response as? HTTPURLResponse,
                          http.statusCode == 206,
                          !data.isEmpty
                    else {
                        throw FMP4ParseError.rangeNotSupported(
                            statusCode: (response as? HTTPURLResponse)?.statusCode
                        )
                    }
                }
            }
            try await group.waitForAll()
        }
    }

    private static func parseBoxes(data: Data) throws -> FMP4Info {
        var moovEnd: Int? = nil
        var sidxInfo: (start: Int, end: Int)? = nil
        var sidx: ParsedSidx? = nil

        var offset = 0
        while offset + 8 <= data.count {
            let size32 = data.readUInt32BE(at: offset)
            let type = data.readASCII(at: offset + 4, length: 4)

            let boxSize: Int
            let payloadStart: Int
            if size32 == 1 {
                guard offset + 16 <= data.count else { throw FMP4ParseError.truncated }
                boxSize = Int(data.readUInt64BE(at: offset + 8))
                payloadStart = offset + 16
            } else if size32 == 0 {
                break // box extends to EOF, stop walking
            } else {
                boxSize = Int(size32)
                payloadStart = offset + 8
            }

            guard boxSize >= 8 else { throw FMP4ParseError.truncated }
            let boxEnd = offset + boxSize

            switch type {
            case "moov":
                moovEnd = boxEnd
            case "sidx":
                sidxInfo = (start: offset, end: boxEnd)
                guard boxEnd <= data.count else { throw FMP4ParseError.truncated }
                sidx = try parseSidx(data: data, payloadStart: payloadStart, end: boxEnd)
            case "moof":
                // first fragment — we should have everything we need
                offset = boxEnd
                guard sidx != nil else { throw FMP4ParseError.missingSidx }
                return try assemble(moovEnd: moovEnd, sidxInfo: sidxInfo, sidx: sidx!)
            default:
                break
            }

            offset = boxEnd
        }

        guard let sidx, let sidxInfo else { throw FMP4ParseError.missingSidx }
        return try assemble(moovEnd: moovEnd, sidxInfo: sidxInfo, sidx: sidx)
    }

    private static func assemble(moovEnd: Int?, sidxInfo: (start: Int, end: Int)?, sidx: ParsedSidx) throws -> FMP4Info {
        // HLS init segment = ftyp + moov bytes from start.
        let initSize = moovEnd ?? sidxInfo?.start ?? 0

        // sidx.firstOffset is from the end of the sidx box.
        guard let sidxEnd = sidxInfo?.end else { throw FMP4ParseError.missingSidx }
        var runningOffset = sidxEnd + Int(sidx.firstOffset)
        var segments: [FMP4Segment] = []
        var total: Double = 0
        let ts = Double(sidx.timescale)

        for ref in sidx.references {
            let dur = Double(ref.duration) / ts
            segments.append(FMP4Segment(offset: runningOffset, size: Int(ref.size), duration: dur))
            runningOffset += Int(ref.size)
            total += dur
        }

        return FMP4Info(initSize: initSize, segments: segments, totalDuration: total)
    }

    // MARK: - sidx

    private struct ParsedSidx {
        let timescale: UInt32
        let firstOffset: UInt64
        let references: [Reference]
        struct Reference { let size: UInt32; let duration: UInt32 }
    }

    private static func parseSidx(data: Data, payloadStart: Int, end: Int) throws -> ParsedSidx {
        var p = payloadStart
        let version = data[p]
        p += 1
        p += 3 // flags
        p += 4 // reference_ID
        let timescale = data.readUInt32BE(at: p); p += 4

        let firstOffset: UInt64
        if version == 0 {
            p += 4 // earliest_presentation_time (32-bit)
            firstOffset = UInt64(data.readUInt32BE(at: p)); p += 4
        } else if version == 1 {
            p += 8 // earliest_presentation_time (64-bit)
            firstOffset = data.readUInt64BE(at: p); p += 8
        } else {
            throw FMP4ParseError.unsupportedSidxVersion
        }

        p += 2 // reserved
        let refCount = Int(data.readUInt16BE(at: p)); p += 2

        var refs: [ParsedSidx.Reference] = []
        refs.reserveCapacity(refCount)
        for _ in 0..<refCount {
            guard p + 12 <= end else { throw FMP4ParseError.truncated }
            let sizeAndType = data.readUInt32BE(at: p); p += 4
            let size = sizeAndType & 0x7FFF_FFFF
            let dur = data.readUInt32BE(at: p); p += 4
            p += 4 // SAP info, ignored
            refs.append(.init(size: size, duration: dur))
        }

        return ParsedSidx(timescale: timescale, firstOffset: firstOffset, references: refs)
    }
}

nonisolated private extension Data {
    func readUInt16BE(at offset: Int) -> UInt16 {
        (UInt16(self[offset]) << 8) | UInt16(self[offset + 1])
    }
    func readUInt32BE(at offset: Int) -> UInt32 {
        (UInt32(self[offset]) << 24) |
        (UInt32(self[offset + 1]) << 16) |
        (UInt32(self[offset + 2]) << 8) |
         UInt32(self[offset + 3])
    }
    func readUInt64BE(at offset: Int) -> UInt64 {
        var v: UInt64 = 0
        for i in 0..<8 { v = (v << 8) | UInt64(self[offset + i]) }
        return v
    }
    func readASCII(at offset: Int, length: Int) -> String {
        String(bytes: self[offset..<offset + length], encoding: .ascii) ?? ""
    }
}
