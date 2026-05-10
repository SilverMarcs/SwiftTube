import Foundation

struct SponsorSegment: Hashable {
    let start: Double
    let end: Double
}

enum SponsorBlockService {
    /// Free public API. Fetches `sponsor` segments only, per project scope.
    static func fetchSponsorSegments(for videoId: String) async -> [SponsorSegment] {
        guard var components = URLComponents(string: "https://sponsor.ajay.app/api/skipSegments") else {
            return []
        }
        components.queryItems = [
            URLQueryItem(name: "videoID", value: videoId),
            URLQueryItem(name: "category", value: "sponsor")
        ]
        guard let url = components.url else { return [] }

        struct Entry: Decodable {
            let segment: [Double]
            let category: String
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            // 404 means "no segments" — common, expected.
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                return []
            }
            let entries = try JSONDecoder().decode([Entry].self, from: data)
            return entries.compactMap { entry in
                guard entry.segment.count == 2,
                      entry.segment[0].isFinite, entry.segment[1].isFinite,
                      entry.segment[1] > entry.segment[0] else { return nil }
                return SponsorSegment(start: entry.segment[0], end: entry.segment[1])
            }.sorted { $0.start < $1.start }
        } catch {
            return []
        }
    }
}
