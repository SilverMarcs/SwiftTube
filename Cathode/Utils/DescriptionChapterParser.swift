import Foundation

struct DescriptionChapter: Hashable {
    let seconds: Double
    let title: String
}

enum DescriptionChapterParser {
    /// Parses chapter timestamps from a YouTube-style description. Recognized
    /// formats per line: `M:SS Title`, `MM:SS Title`, `H:MM:SS Title`.
    /// Per YouTube convention, the first chapter must be at 0:00 — otherwise
    /// the result is not treated as a chapter list.
    static func parse(_ description: String) -> [DescriptionChapter] {
        guard !description.isEmpty else { return [] }

        let pattern = #"(?m)^\s*(?:(\d{1,2}):)?(\d{1,2}):(\d{2})\s+([^\n]+?)\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let nsDescription = description as NSString
        let matches = regex.matches(in: description, range: NSRange(location: 0, length: nsDescription.length))

        var chapters: [DescriptionChapter] = []
        for match in matches where match.numberOfRanges == 5 {
            let h = match.range(at: 1).location == NSNotFound
                ? 0
                : Int(nsDescription.substring(with: match.range(at: 1))) ?? 0
            let m = Int(nsDescription.substring(with: match.range(at: 2))) ?? 0
            let s = Int(nsDescription.substring(with: match.range(at: 3))) ?? 0
            let title = nsDescription.substring(with: match.range(at: 4))
                .trimmingCharacters(in: .whitespaces)
            let total = Double(h * 3600 + m * 60 + s)
            if !title.isEmpty {
                chapters.append(DescriptionChapter(seconds: total, title: title))
            }
        }

        chapters.sort { $0.seconds < $1.seconds }
        guard chapters.first?.seconds == 0 else { return [] }
        return chapters
    }
}
