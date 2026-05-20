//
//  YTService+Channel.swift
//  Cathode
//
//  InnerTube-backed channel lookup. Handles are resolved transparently by
//  `InnerTubeAPI.fetchChannel(channelId:)` (it accepts both `UC…` ids and
//  `@handle` strings).
//

import Foundation

extension YTService {
    static func fetchChannel(forHandle handle: String) async throws -> Channel {
        // Ensure the handle has the leading `@` that InnerTube expects.
        let normalised: String = handle.hasPrefix("@") ? handle : "@\(handle.trimmingCharacters(in: CharacterSet(charactersIn: "@")))"
        let (it, _) = try await InnerTubeAPI.shared.fetchChannel(channelId: normalised)
        return Channel(it)
    }

    static func fetchChannel(byId channelId: String) async throws -> Channel {
        let (it, _) = try await InnerTubeAPI.shared.fetchChannel(channelId: channelId)
        return Channel(it)
    }

    /// Bounded-concurrency fan-out: InnerTube exposes no batched channel endpoint.
    static func fetchChannels(byIds channelIds: [String]) async throws -> [Channel] {
        guard !channelIds.isEmpty else { return [] }

        let result: [String: Channel] = await withTaskGroup(
            of: (String, Channel?).self,
            returning: [String: Channel].self
        ) { group in
            let maxConcurrent = 6
            var inFlight = 0
            var iterator = channelIds.makeIterator()

            func addNext() {
                guard let id = iterator.next() else { return }
                inFlight += 1
                group.addTask {
                    do {
                        let (it, _) = try await InnerTubeAPI.shared.fetchChannel(channelId: id)
                        return (id, Channel(it))
                    } catch {
                        return (id, nil)
                    }
                }
            }
            for _ in 0..<min(maxConcurrent, channelIds.count) { addNext() }

            var collected: [String: Channel] = [:]
            while inFlight > 0 {
                if let (id, ch) = await group.next() {
                    inFlight -= 1
                    if let ch = ch { collected[id] = ch }
                    addNext()
                }
            }
            return collected
        }

        // Preserve input order for the subset that resolved.
        return channelIds.compactMap { result[$0] }
    }
}
